import Foundation

/// Reading what ffmpeg, ffprobe and Parakeet report. Pure functions over their text, so each one
/// is unit-tested on the exact output the tools printed on this Mac (ffmpeg 9.0.1, 10 Oct).
enum Measure {
    // MARK: ffprobe

    struct Probe: Equatable, Sendable {
        let duration: Double
        let hasAudio: Bool
    }

    /// `ffprobe -v error -show_entries format=duration:stream=codec_type -of json <file>`.
    /// Nil when the file has no duration yet (it does not open).
    static func probe(json: String) -> Probe? {
        struct Payload: Decodable {
            struct Stream: Decodable { let codec_type: String? }
            struct Format: Decodable { let duration: String? }
            let streams: [Stream]?
            let format: Format?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(json.utf8)),
              let duration = payload.format?.duration.flatMap(Double.init), duration > 0 else { return nil }
        let hasAudio = (payload.streams ?? []).contains { $0.codec_type == "audio" }
        return Probe(duration: duration, hasAudio: hasAudio)
    }

    // MARK: Sound check (volumedetect)

    struct Volume: Equatable, Sendable {
        /// The loudest sample, in dB. -infinity when the track is all digital zeros.
        let max: Double
        let mean: Double
    }

    /// `ffmpeg ... -af volumedetect -f null -` prints its numbers on stderr. The first match is
    /// used, as engine v0 does: ffmpeg also prints an empty first instance with only n_samples: 0.
    static func volume(stderr: String) -> Volume {
        func value(_ name: String) -> Double {
            guard let match = stderr.firstMatch(of: try! Regex("\(name): (-?[0-9.]+|-inf) dB")),
                  let text = match.output[1].substring.map(String.init) else { return -.infinity }
            return text == "-inf" ? -.infinity : (Double(text) ?? -.infinity)
        }
        return Volume(max: value("max_volume"), mean: value("mean_volume"))
    }

    // MARK: Loudness (loudnorm first pass)

    /// The numbers loudnorm's first pass measures, kept as the exact strings it printed, because
    /// they are handed back to the second pass as they are (engine v0 does the same).
    struct LoudnormPass: Equatable, Sendable {
        let inputI: String
        let inputTP: String
        let inputLRA: String
        let inputThresh: String
        let targetOffset: String
        let normalizationType: String

        var inputLUFS: Double? { Double(inputI) }
    }

    /// The JSON block loudnorm prints last on stderr with `print_format=json`.
    static func loudnorm(stderr: String) -> LoudnormPass? {
        guard let open = stderr.lastIndex(of: "{"), let close = stderr.lastIndex(of: "}"), open < close else { return nil }
        let json = String(stderr[open...close])
        guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { return nil }
        func field(_ key: String) -> String? { object[key] as? String }
        guard let i = field("input_i"), let tp = field("input_tp"), let lra = field("input_lra"),
              let thresh = field("input_thresh"), let offset = field("target_offset") else { return nil }
        return LoudnormPass(inputI: i, inputTP: tp, inputLRA: lra, inputThresh: thresh, targetOffset: offset,
                            normalizationType: field("normalization_type") ?? "")
    }

    // MARK: Loudness of the finished file (ebur128)

    struct Loudness: Equatable, Sendable {
        let integratedLUFS: Double
        let truePeakDBFS: Double
    }

    /// The summary `ebur128=peak=true` prints at the end: the last "I: ... LUFS" and the last
    /// "Peak: ... dBFS" lines, as engine v0 reads them.
    static func ebur128(stderr: String) -> Loudness? {
        func last(_ pattern: String) -> Double? {
            let regex = try! Regex(pattern)
            guard let match = stderr.matches(of: regex).last, let text = match.output[1].substring else { return nil }
            return Double(text)
        }
        guard let i = last(#"I:\s+(-?[0-9.]+) LUFS"#), let peak = last(#"Peak:\s+(-?[0-9.]+) dBFS"#) else { return nil }
        return Loudness(integratedLUFS: i, truePeakDBFS: peak)
    }

    // MARK: Transcript coverage

    /// The end of the last cue in an .srt, in whole seconds (engine v0 drops the milliseconds).
    static func lastCueEnd(srt: String) -> Double {
        var last = 0
        for match in srt.matches(of: /--> (\d+):(\d+):(\d+)[,.](\d+)/) {
            let h = Int(match.output.1) ?? 0, m = Int(match.output.2) ?? 0, s = Int(match.output.3) ?? 0
            last = max(last, h * 3600 + m * 60 + s)
        }
        return Double(last)
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
