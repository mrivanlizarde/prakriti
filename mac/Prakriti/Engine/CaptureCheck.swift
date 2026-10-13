import Foundation

// The capture check (v2 part M4b; docs/v2/PLAN.md M4; REQUEST item 1, "plan for clean inputs"). The first
// step of every recording, right after the file is complete: every stream measured by ffprobe (picture size,
// frame rate, codec, color tags, chapters, the container), every audio track measured on its own
// (`-map 0:a:N`: loudness and true peak by ebur128, the loudest and average sample by volumedetect, and for a
// track with two channels the difference of left and right), and each finding written as a plain line with a
// capture tip and a Help article. It changes nothing and makes nothing: a poor recording is still made, and
// the inspector's Checks say what to change before the next one.
//
// Why each rule is here:
// - One microphone copied to two channels ("dual mono") is the known state of every studio file so far
//   (START_HERE warnings 6 and 14): one voice cannot be told from another on it. Left minus right at or under
//   -60 dB is the test (measured on the 13 Sep talk: -91 dB, digital zero, 12 Oct).
// - A player plays only the first track, so a file can sound right and still be missing the others (Help 10).
// - A silent track is the 14 Sep lesson: a class recorded silent and nobody knew for 24 days.

/// What the capture check measured on one recording, kept on the recording as JSON (`Recording.captureJSON`).
struct CaptureReport: Codable, Equatable, Sendable {
    /// "MOV", "MP4", "Matroska (MKV)", or the file's own extension in capitals for a sound file.
    var container: String
    /// The first picture stream, or nil for a sound file.
    var video: VideoStream?
    /// More picture streams than the first (a camera and a screen in one file), counted only.
    var otherVideoStreams = 0
    var audio: [AudioTrack] = []
    var chapters = 0
    var duration: Double?
    var findings: [CaptureFinding] = []
    var measuredAt: Date
    /// The rules this report was written with, so a later part can tell an older report.
    var version = CaptureCheck.version

    struct VideoStream: Codable, Equatable, Sendable {
        var codec: String
        var profile: String?
        var width: Int
        var height: Int
        /// Frames per second from the stream's own rate (`r_frame_rate`), and its average (`avg_frame_rate`).
        var frameRate: Double?
        var averageFrameRate: Double?
        var colorSpace: String?
        var colorTransfer: String?
        var colorPrimaries: String?
        var colorRange: String?
    }

    struct AudioTrack: Codable, Equatable, Sendable {
        /// The track's place among the audio tracks, from 1 (OBS's "Track 1").
        var number: Int
        var codec: String
        var sampleRate: Int?
        var channels: Int
        var layout: String?
        /// What ebur128 measured over the whole track: integrated loudness and true peak. Nil for a silent track
        /// (ebur128 has nothing to gate) or one that could not be measured.
        var integratedLUFS: Double?
        var truePeakDBTP: Double?
        /// What volumedetect measured: the loudest sample and the average, in dB (-91 is digital zero).
        var loudestDB: Double?
        var averageDB: Double?
        /// The loudest sample of left minus right, for a track with two or more channels. At or under -60 dB the
        /// two channels carry the same sound: one microphone copied to both.
        var differenceDB: Double?
        /// False when ffmpeg could not read the track.
        var measured = true

        var isSilent: Bool { measured && (loudestDB ?? -.infinity) <= CaptureCheck.silentAtOrBelow }
        var isDualMono: Bool {
            guard measured, channels >= 2, !isSilent, let difference = differenceDB else { return false }
            return difference <= CaptureCheck.sameChannelsAtOrBelow
        }
    }

    /// The findings to act on: anything short of a pass, except a track's own row, which only sums up the
    /// problems listed under it.
    var warnings: [CaptureFinding] { findings.filter { $0.level != .pass && $0.kind != .track } }

    /// One sentence for the top of the Capture section and the step's line.
    var summary: String {
        let count = warnings.count
        if count == 0 { return "Recorded well. Nothing to change before the next recording." }
        return (count == 1 ? "One thing" : CaptureCheck.word(count).capitalizedFirst + " things") + " to change before the next recording."
    }

    /// The step's line in Activity and the inspector's steps: "1920 by 1080, 29.97 fps, H.264. 1 audio track. ..."
    var stepLine: String {
        var parts: [String] = []
        if let video {
            parts.append("\(video.width) by \(video.height)" + (video.frameRate.map { ", " + CaptureCheck.rate($0) + " fps" } ?? "")
                         + ", " + CaptureCheck.codecName(video.codec) + ".")
        } else {
            parts.append("No picture.")
        }
        parts.append(Format.count(audio.count, "audio track") + ".")
        parts.append(summary)
        return parts.joined(separator: " ")
    }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String?) -> CaptureReport? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CaptureReport.self, from: data)
    }
}

/// One row of the Capture section (design spec 3.5.4): what was checked, the measured value, the limit in
/// words, and for anything short of a pass a capture tip and the Help article that explains it.
struct CaptureFinding: Codable, Equatable, Sendable, Identifiable {
    enum Level: String, Codable, Sendable {
        case pass, warn, fail

        /// The symbols design spec 3.5.4 names.
        var symbol: String {
            switch self {
            case .pass: "checkmark.circle"
            case .warn: "exclamationmark.triangle"
            case .fail: "xmark.octagon"
            }
        }

        var title: String {
            switch self {
            case .pass: "Passes"
            case .warn: "Change before the next recording"
            case .fail: "Not usable"
            }
        }
    }

    enum Kind: String, Codable, Sendable {
        case container, picture, pictureSize, frameRate, videoCodec, color, chapters
        case audioTracks, track, silent, dualMono, quiet, peak, sampleRate, notMeasured
    }

    /// Stable, so a test or a later part can find a row: "track-1-dual-mono".
    var id: String
    var kind: Kind
    var level: Level
    /// What was checked: "Picture size", "Track 1".
    var title: String
    /// What was measured, in plain words.
    var value: String
    /// The limit, in words.
    var limit: String
    /// What to change before the next recording. Every finding short of a pass has one.
    var tip: String?
    /// The Help article that explains it, by id.
    var help: String?
}

/// The check itself: reading ffprobe's and ffmpeg's text is pure (tested on the exact output the tools printed
/// here), and `run` asks the tools through the caller, so the pipeline's progress meter and time limits apply.
enum CaptureCheck {
    static let version = 1
    /// A track whose loudest sample is at or under this is silent: the sound check's own limit (-60 dB).
    static let silentAtOrBelow: Double = -60
    /// Left minus right at or under this: the two channels carry the same sound.
    static let sameChannelsAtOrBelow: Double = -60
    /// Speech quieter than this, over the whole track, is too quiet: hiss rises when it is brought up.
    static let quietBelowLUFS: Double = -35
    /// A true peak at or above this is at the top of what the file can hold, and may have distorted.
    static let peakAtOrAbove: Double = -0.5

    /// The Help articles a finding links to, with the titles the Checks tab shows (HelpTests checks they exist).
    static let helpTitles: [String: String] = [
        "capture-the-best-video": "Capture the best video",
        "set-up-obs-for-prakriti": "Set up OBS for Prakriti",
        "troubleshooting": "If something isn't working",
    ]

    // MARK: ffprobe

    /// `ffprobe -v error -show_streams -show_format -show_chapters -of json <file>`. Nil when it is not JSON.
    static func probe(json: String, fileName: String) -> CaptureReport? {
        struct Payload: Decodable {
            struct Stream: Decodable {
                let codec_type: String?
                let codec_name: String?
                let profile: String?
                let width: Int?
                let height: Int?
                let r_frame_rate: String?
                let avg_frame_rate: String?
                let color_space: String?
                let color_transfer: String?
                let color_primaries: String?
                let color_range: String?
                let sample_rate: String?
                let channels: Int?
                let channel_layout: String?
                let disposition: [String: Int]?
            }
            struct Format: Decodable {
                let format_name: String?
                let duration: String?
                let tags: [String: String]?
            }
            let streams: [Stream]?
            let chapters: [[String: AnyDecodable]]?
            let format: Format?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(json.utf8)) else { return nil }
        let streams = payload.streams ?? []
        // A cover picture inside a sound file is a "video" stream to ffprobe; it is not a picture recorded.
        let pictures = streams.filter { $0.codec_type == "video" && ($0.disposition?["attached_pic"] ?? 0) == 0 }
        let video = pictures.first.map {
            CaptureReport.VideoStream(codec: $0.codec_name ?? "unknown", profile: $0.profile, width: $0.width ?? 0, height: $0.height ?? 0,
                                      frameRate: fraction($0.r_frame_rate), averageFrameRate: fraction($0.avg_frame_rate),
                                      colorSpace: tag($0.color_space), colorTransfer: tag($0.color_transfer),
                                      colorPrimaries: tag($0.color_primaries), colorRange: tag($0.color_range))
        }
        let audio = streams.filter { $0.codec_type == "audio" }.enumerated().map { index, stream in
            CaptureReport.AudioTrack(number: index + 1, codec: stream.codec_name ?? "unknown", sampleRate: stream.sample_rate.flatMap { Int($0) },
                                     channels: stream.channels ?? 1, layout: stream.channel_layout)
        }
        return CaptureReport(container: container(formatName: payload.format?.format_name, brand: payload.format?.tags?["major_brand"], fileName: fileName),
                             video: video, otherVideoStreams: max(0, pictures.count - 1), audio: audio,
                             chapters: payload.chapters?.count ?? 0, duration: payload.format?.duration.flatMap(Double.init), measuredAt: .distantPast)
    }

    /// Any JSON value, read and thrown away (a chapter is only counted).
    struct AnyDecodable: Decodable {
        init(from decoder: Decoder) throws {}
    }

    /// "30000/1001" is 29.97. Nil for "0/0" or anything unreadable.
    static func fraction(_ text: String?) -> Double? {
        guard let parts = text?.split(separator: "/"), parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d > 0, n > 0 else { return nil }
        return n / d
    }

    /// ffprobe writes "unknown" or leaves a tag out when it is not set.
    private static func tag(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value != "unknown", value != "unspecified", value != "reserved" else { return nil }
        return value
    }

    /// The container in words. MOV and MP4 share one ffprobe demuxer, so the brand tells them apart ("qt" is
    /// QuickTime, which OBS's Hybrid MOV writes), then the file's extension.
    static func container(formatName: String?, brand: String?, fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let name = formatName ?? ""
        if name.contains("matroska") || name.contains("webm") || ext == "mkv" { return "Matroska (MKV)" }
        if name.contains("mov") || name.contains("mp4") {
            if brand?.trimmingCharacters(in: .whitespaces) == "qt" || ext == "mov" { return "MOV" }
            if ext == "m4a" { return "M4A" }
            return "MP4"
        }
        return ext.isEmpty ? (name.isEmpty ? "Unknown" : name.uppercased()) : ext.uppercased()
    }

    // MARK: ffmpeg, one track

    /// The arguments that measure audio track `number` (from 1) on its own: ebur128 (loudness and true peak) and
    /// volumedetect on the track, and for two or more channels volumedetect on left minus right, in one read.
    /// `framelog=verbose` keeps ebur128's ten lines a second out of what is read; only its summary is printed.
    static func trackArguments(file: String, number: Int, channels: Int) -> [String] {
        let input = "[0:a:\(number - 1)]"
        let measure = "ebur128=peak=true:framelog=verbose,volumedetect@level"
        if channels >= 2 {
            return ["-hide_banner", "-nostats", "-i", file,
                    "-filter_complex", "\(input)asplit=2[a][b];[a]\(measure)[l];[b]pan=mono|c0=c0-c1,volumedetect@difference[d]",
                    "-map", "[l]", "-map", "[d]", "-f", "null", "-"]
        }
        return ["-hide_banner", "-nostats", "-i", file, "-filter_complex", "\(input)\(measure)[l]", "-map", "[l]", "-f", "null", "-"]
    }

    /// Reads what `trackArguments` printed into the track. Each volumedetect is named, because ffmpeg prints
    /// them in either order and each one once empty before the real numbers.
    static func readTrack(stderr: String, into track: inout CaptureReport.AudioTrack) {
        func volume(_ instance: String, _ name: String) -> Double? {
            let pattern = "\\[volumedetect@\(instance) @ [^\\]]+\\] \(name): (-?[0-9.]+|-inf) dB"
            guard let regex = try? Regex(pattern), let match = stderr.matches(of: regex).last,
                  let text = match.output[1].substring.map(String.init) else { return nil }
            return text == "-inf" ? -.infinity : Double(text)
        }
        track.loudestDB = volume("level", "max_volume")
        track.averageDB = volume("level", "mean_volume")
        track.differenceDB = track.channels >= 2 ? volume("difference", "max_volume") : nil
        let loudness = Measure.ebur128(stderr: stderr)
        // ebur128 reports -70 LUFS when nothing passed its gate: no loudness to speak of.
        track.integratedLUFS = loudness.flatMap { $0.integratedLUFS > -70 ? $0.integratedLUFS : nil }
        track.truePeakDBTP = loudness?.truePeakDBFS
        track.measured = track.loudestDB != nil
    }

    // MARK: Findings

    /// Every finding, in the order the Capture section lists them: the file, the picture, then the sound.
    static func findings(_ report: CaptureReport) -> [CaptureFinding] {
        var out: [CaptureFinding] = []
        let obs = "set-up-obs-for-prakriti", capture = "capture-the-best-video"

        // The container.
        if report.container == "Matroska (MKV)" {
            out.append(CaptureFinding(id: "container", kind: .container, level: .warn, title: "File type", value: "Matroska (MKV). The Mac's own video tools cannot open it.",
                                      limit: "MOV or MP4", tip: "In OBS, set Recording Format to Hybrid MOV or Hybrid MP4.", help: obs))
        } else {
            out.append(CaptureFinding(id: "container", kind: .container, level: .pass, title: "File type", value: report.container,
                                      limit: report.video == nil ? "Any file the Mac can play" : "MOV or MP4"))
        }

        // The picture.
        if let video = report.video {
            let short = min(video.width, video.height), long = max(video.width, video.height)
            let size = "\(video.width) by \(video.height)" + (short >= 2160 ? " (4K)" : short >= 1080 ? " (1080p)" : "")
            if short >= 1080 {
                out.append(CaptureFinding(id: "picture-size", kind: .pictureSize, level: .pass, title: "Picture size", value: size,
                                          limit: "1920 by 1080 or larger. 3840 by 2160 gives room to zoom and to cut vertical clips."))
            } else {
                out.append(CaptureFinding(id: "picture-size", kind: .pictureSize, level: .warn, title: "Picture size", value: size + ", smaller than 1080p",
                                          limit: "1920 by 1080 or larger",
                                          tip: long == 0 ? "Check the camera is chosen as a source in OBS." : "In OBS, set both resolutions to 3840x2160, or 1920x1080 if the Mac cannot keep up.",
                                          help: obs))
            }

            if let fps = video.frameRate {
                let steady = video.averageFrameRate.map { abs($0 - fps) / fps <= 0.01 } ?? true
                let value = rate(fps) + " frames per second" + (steady ? "" : ", but it changes during the recording (average " + rate(video.averageFrameRate ?? 0) + ")")
                if !steady || fps < 23.9 {
                    out.append(CaptureFinding(id: "frame-rate", kind: .frameRate, level: .warn, title: "Frame rate", value: value, limit: "24 to 60, the same for the whole recording",
                                              tip: "In OBS, set Common FPS Values to 30, and keep the same settings for the whole session.", help: obs))
                } else {
                    out.append(CaptureFinding(id: "frame-rate", kind: .frameRate, level: .pass, title: "Frame rate", value: value, limit: "24 to 60, the same for the whole recording"))
                }
            }

            let codec = codecName(video.codec) + (video.profile.map { " (\($0))" } ?? "")
            if ["h264", "hevc", "prores"].contains(video.codec) {
                out.append(CaptureFinding(id: "video-codec", kind: .videoCodec, level: .pass, title: "Video codec", value: codec, limit: "H.264, HEVC or ProRes"))
            } else {
                out.append(CaptureFinding(id: "video-codec", kind: .videoCodec, level: .warn, title: "Video codec", value: codec, limit: "H.264, HEVC or ProRes",
                                          tip: "In OBS, set Video Encoder to Apple VT HEVC Hardware Encoder.", help: obs))
            }

            let tagged = [video.colorSpace, video.colorPrimaries, video.colorTransfer].compactMap { $0 }
            let range = video.colorRange == "pc" ? "full range" : video.colorRange == "tv" ? "limited range" : nil
            let colorLimit = "Rec. 709, limited range"
            if tagged.isEmpty {
                out.append(CaptureFinding(id: "color", kind: .color, level: .warn, title: "Color", value: "Not tagged, so players may guess the colors differently",
                                          limit: colorLimit, tip: "In OBS, Advanced: set Color Space to Rec. 709 and Color Range to Limited.", help: obs))
            } else if tagged.allSatisfy({ $0 == "bt709" }) && video.colorRange != "pc" {
                out.append(CaptureFinding(id: "color", kind: .color, level: .pass, title: "Color", value: "Rec. 709" + (range.map { ", " + $0 } ?? ""), limit: colorLimit))
            } else {
                let named = Array(Set(tagged)).sorted().map(colorName).joined(separator: ", ")
                out.append(CaptureFinding(id: "color", kind: .color, level: .warn, title: "Color", value: named + (range.map { ", " + $0 } ?? ""),
                                          limit: colorLimit, tip: "In OBS, Advanced: set Color Space to Rec. 709 and Color Range to Limited.", help: obs))
            }

            out.append(CaptureFinding(id: "chapters", kind: .chapters, level: .pass, title: "Chapter markers",
                                      value: report.chapters == 0 ? "None" : Format.count(report.chapters, "marker"),
                                      limit: "Optional. The OBS chapter marker key adds one while you record."))
        } else {
            out.append(CaptureFinding(id: "picture", kind: .picture, level: .pass, title: "Picture", value: "None. This is a sound file.", limit: "A picture is optional"))
        }

        // The sound: how many tracks.
        switch report.audio.count {
        case 0:
            out.append(CaptureFinding(id: "audio-tracks", kind: .audioTracks, level: .fail, title: "Audio tracks", value: "None. The file has no sound.",
                                      limit: "One track for the mix and one for each microphone",
                                      tip: "In OBS, Output, Recording: select Audio Track 1, and one more track for each microphone.", help: obs))
        case 1:
            out.append(CaptureFinding(id: "audio-tracks", kind: .audioTracks, level: .warn, title: "Audio tracks", value: "1 track, so every voice is in one mix",
                                      limit: "One track for the mix and one for each microphone",
                                      tip: "In OBS, record each microphone on its own track as well as the mix on track 1.", help: obs))
        default:
            out.append(CaptureFinding(id: "audio-tracks", kind: .audioTracks, level: .pass, title: "Audio tracks", value: Format.count(report.audio.count, "track"),
                                      limit: "One track for the mix and one for each microphone"))
        }

        // Each track on its own.
        for track in report.audio {
            let n = track.number, name = "Track \(n)"
            guard track.measured else {
                out.append(CaptureFinding(id: "track-\(n)", kind: .notMeasured, level: .warn, title: name, value: describe(track) + ". It could not be measured.",
                                          limit: "Every track measured", tip: "Record a 10-second test and check it plays in QuickTime Player.", help: "troubleshooting"))
                continue
            }
            var problems: [CaptureFinding] = []
            if track.isSilent {
                // The first track is what everything is made from; a silent extra track may be a microphone left off.
                problems.append(CaptureFinding(id: "track-\(n)-silent", kind: .silent, level: n == 1 ? .fail : .warn, title: "\(name), silent",
                                               value: "No sound: the loudest moment is " + Pipeline.db(track.loudestDB ?? -.infinity) + ".",
                                               limit: "Louder than -60 dB somewhere",
                                               tip: "Check the microphone is not muted in OBS and moves on its meter, then record a 10-second test.", help: "troubleshooting"))
            }
            if track.isDualMono {
                problems.append(CaptureFinding(id: "track-\(n)-dual-mono", kind: .dualMono, level: .warn, title: "\(name), one microphone in both channels",
                                               value: "Left and right are the same sound (they differ by " + Pipeline.db(track.differenceDB ?? -.infinity)
                                                + " at most), so one voice cannot be told from another.",
                                               limit: "Each speaker on a separate track",
                                               tip: "Give each speaker a microphone on its own track.", help: capture))
            }
            if !track.isSilent, let lufs = track.integratedLUFS, lufs < quietBelowLUFS {
                problems.append(CaptureFinding(id: "track-\(n)-quiet", kind: .quiet, level: .warn, title: "\(name), quiet",
                                               value: Format.lufs(lufs) + " over the whole track.", limit: "Speech louder than \(Int(quietBelowLUFS)) LUFS",
                                               tip: "Raise the microphone's gain so speech sits in the upper yellow of the OBS meter.", help: capture))
            }
            if !track.isSilent, let peak = track.truePeakDBTP, peak >= peakAtOrAbove {
                problems.append(CaptureFinding(id: "track-\(n)-peak", kind: .peak, level: .warn, title: "\(name), loudest moments at the top",
                                               value: "Peak " + String(format: "%.1f", peak) + " dB, where sound distorts.",
                                               limit: "Peak under \(String(format: "%.1f", peakAtOrAbove)) dB",
                                               tip: "Lower the microphone's gain so the loudest words only touch the start of the red.", help: capture))
            }
            if let rate = track.sampleRate, rate != 48000 {
                problems.append(CaptureFinding(id: "track-\(n)-sample-rate", kind: .sampleRate, level: .warn, title: "\(name), sample rate",
                                               value: kHz(rate) + ".", limit: "48 kHz, the rate video uses",
                                               tip: "In OBS, Audio: set Sample Rate to 48 kHz.", help: obs))
            }
            let worst: CaptureFinding.Level = problems.contains { $0.level == .fail } ? .fail : problems.isEmpty ? .pass : .warn
            out.append(CaptureFinding(id: "track-\(n)", kind: .track, level: worst, title: name, value: describe(track),
                                      limit: "48 kHz, speech louder than -35 LUFS, peak under -0.5 dB"))
            out += problems
        }
        return out
    }

    /// "Stereo, 48 kHz, AAC. -26.7 LUFS, peak -3.1 dB" for a track's own row.
    static func describe(_ track: CaptureReport.AudioTrack) -> String {
        let layout = track.channels == 1 ? "Mono" : track.channels == 2 ? "Stereo" : "\(track.channels) channels"
        var line = layout + (track.sampleRate.map { ", " + kHz($0) } ?? "") + ", " + codecName(track.codec)
        if track.measured {
            if track.isSilent {
                line += ". Silent"
            } else if let lufs = track.integratedLUFS {
                line += ". " + Format.lufs(lufs) + (track.truePeakDBTP.map { ", peak " + String(format: "%.1f", $0) + " dB" } ?? "")
            }
        }
        return line
    }

    // MARK: Words

    static func codecName(_ codec: String) -> String {
        switch codec {
        case "h264": "H.264"
        case "hevc": "HEVC"
        case "prores": "ProRes"
        case "aac": "AAC"
        case "alac": "Apple Lossless"
        case "mp3": "MP3"
        case "opus": "Opus"
        case let pcm where pcm.hasPrefix("pcm_"): "Uncompressed"
        default: codec.uppercased()
        }
    }

    static func colorName(_ tag: String) -> String {
        switch tag {
        case "bt709": "Rec. 709"
        case "bt2020nc", "bt2020c", "bt2020": "Rec. 2020 (wide color)"
        case "smpte2084": "PQ (HDR)"
        case "arib-std-b67": "HLG (HDR)"
        case "smpte170m", "bt470bg", "bt601": "Rec. 601 (standard definition)"
        default: tag
        }
    }

    /// "29.97", "30", "59.94".
    static func rate(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(format: "%.0f", rounded) : String(format: "%.2f", rounded)
    }

    static func kHz(_ rate: Int) -> String {
        rate % 1000 == 0 ? "\(rate / 1000) kHz" : String(format: "%.1f kHz", Double(rate) / 1000)
    }

    static func word(_ n: Int) -> String {
        ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"].indices.contains(n)
            ? ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"][n] : "\(n)"
    }

    // MARK: Running it

    /// Measures `file`: ffprobe once (held by `control` while the make is paused), then one ffmpeg read per audio
    /// track through `measureTrack`, which the pipeline gives (so its meter, pause and time limit apply). A track that cannot be read is written down as
    /// not measured and the check goes on: the capture check never stops a make. Cancellation stops it.
    static func run(file: URL, tools: ToolPaths, now: Date, control: ProcessControl? = nil,
                    tracksKnown: @Sendable (Int) -> Void = { _ in },
                    measureTrack: @Sendable (_ arguments: [String]) async throws -> String) async throws -> CaptureReport {
        let probe = try? await Subprocess.run(tools.ffprobe, ["-v", "error", "-show_streams", "-show_format", "-show_chapters", "-of", "json", file.path],
                                              timeout: .seconds(120), control: control)
        try Task.checkCancellation()
        guard let probe, var report = Self.probe(json: probe.stdout, fileName: file.lastPathComponent) else {
            var report = CaptureReport(container: container(formatName: nil, brand: nil, fileName: file.lastPathComponent), measuredAt: now)
            report.findings = [CaptureFinding(id: "probe", kind: .notMeasured, level: .warn, title: "Streams", value: "ffprobe could not read the file's streams.",
                                              limit: "Every stream measured", tip: "Record a 10-second test and check it plays in QuickTime Player.",
                                              help: "troubleshooting")]
            return report
        }
        report.measuredAt = now
        tracksKnown(report.audio.count)
        for index in report.audio.indices {
            let arguments = trackArguments(file: file.path, number: report.audio[index].number, channels: report.audio[index].channels)
            do {
                let stderr = try await measureTrack(arguments)
                readTrack(stderr: stderr, into: &report.audio[index])
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                report.audio[index].measured = false
            }
        }
        report.findings = findings(report)
        return report
    }
}
