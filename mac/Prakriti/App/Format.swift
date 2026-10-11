import Foundation

/// How numbers and dates read on screen. Weekdays are always computed from the date, never
/// written by hand (five wrong weekday labels once shipped in a care file and a sent recap).
enum Format {
    static let locale = Locale(identifier: "en_GB")

    private static func formatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }

    /// "Sun 13 Sep"
    static func dayLabel(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter("EEE d MMM", timeZone: timeZone).string(from: date)
    }

    /// "Saturday 10 October"
    static func longDay(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter("EEEE d MMMM", timeZone: timeZone).string(from: date)
    }

    /// "Sun 13 Sep 2026 at 6:25 pm"
    static func dayAndTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let day = formatter("EEE d MMM yyyy", timeZone: timeZone).string(from: date)
        return day + " at " + clock(date, timeZone: timeZone)
    }

    /// "6:25 pm"
    static func clock(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = formatter("h:mm a", timeZone: timeZone)
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: date)
    }

    /// Plain words for a length: "45 s", "1 min 30 s", "15 min 48 s", "1 hr 2 min".
    static func length(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s >= 3600 {
            // Over an hour, to the nearest minute: 1:01:42 reads as "1 hr 2 min".
            let minutes = Int((Double(s) / 60).rounded())
            let h = minutes / 60, m = minutes % 60
            return m > 0 ? "\(h) hr \(m) min" : "\(h) hr"
        }
        let m = s / 60, x = s % 60
        if m > 0 { return x > 0 ? "\(m) min \(x) s" : "\(m) min" }
        return "\(x) s"
    }

    /// A timecode, as the transcript shows it: "15:47", "1:01:42".
    static func timecode(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        let mm = h > 0 ? String(format: "%02d", m) : String(m)
        return (h > 0 ? "\(h):" : "") + mm + ":" + String(format: "%02d", x)
    }

    /// "0.73 GB", "120 MB"
    static func size(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1e9
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1e6)
    }

    /// "420 KB" (1,024 bytes each, as artwork limits are written), or "1.4 MB" from 1 MB up.
    static func kilobytes(_ bytes: Int64) -> String {
        bytes < 1_048_576 ? String(format: "%.0f KB", Double(bytes) / 1024) : String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    /// "40.1 MB": a podcast file's size, to a tenth, as hosts show it.
    static func megabytes(_ bytes: Int64) -> String { String(format: "%.1f MB", Double(bytes) / 1e6) }

    /// "-16.8 LUFS"
    static func lufs(_ value: Double) -> String { String(format: "%.1f LUFS", value) }

    /// A target, in whole units: "-16 LUFS"
    static func loudnessTarget(_ value: Double) -> String { String(format: "%.0f LUFS", value) }

    /// "-1.6 dBFS"
    static func dbfs(_ value: Double) -> String { String(format: "%.1f dBFS", value) }

    /// "1 recording", "3 recordings"
    static func count(_ n: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(n) " + (n == 1 ? singular : (plural ?? singular + "s"))
    }

    /// A model id as people read it: "qwen/qwen3.8-27b" reads "Qwen3.8-27B". The publisher before
    /// the slash is dropped, the first letter is capitalised, and a size like "27b" becomes "27B".
    static func modelName(_ id: String) -> String {
        let name = id.split(separator: "/").last.map(String.init) ?? id
        guard !name.isEmpty else { return id }
        let sized = name.replacing(/(\d)b\b/) { "\($0.1)B" }
        return sized.prefix(1).uppercased() + sized.dropFirst()
    }

    /// ", 1.2 s of silence trimmed": after an episode's length, when the trim took any.
    static func trimmed(start: Double?, end: Double?) -> String {
        let total = (start ?? 0) + (end ?? 0)
        return total < 0.05 ? "" : String(format: ", %.1f s of silence trimmed", total)
    }

    /// "episode.mp3, REPORT.md, transcript (.txt, .srt, .md, .json)": the files a make left, the
    /// transcript's formats grouped so the line stays short.
    static func madeFiles(_ names: [String]) -> String {
        let transcript = names.filter { $0.hasPrefix("transcript.") }
        let order = ["txt", "srt", "vtt", "md", "json"]
        let formats = transcript.map { String($0.dropFirst("transcript.".count)) }
            .sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
        var parts = names.filter { !$0.hasPrefix("transcript.") }.sorted { $0.lowercased() < $1.lowercased() }
        if !formats.isEmpty { parts.append("transcript (" + formats.map { "." + $0 }.joined(separator: ", ") + ")") }
        return parts.joined(separator: ", ")
    }

    /// "-16 LUFS, silence trimmed, mono, no intro or outro"
    static func episodeSettings(_ setting: OutputSetting) -> String {
        var parts = [loudnessTarget(setting.loudnessTarget)]
        parts.append(setting.trimSilence ? "silence trimmed" : "silence kept")
        parts.append(setting.channels.title.lowercased())
        switch (setting.introPath != nil, setting.outroPath != nil) {
        case (true, true): parts.append("intro and outro")
        case (true, false): parts.append("intro")
        case (false, true): parts.append("outro")
        case (false, false): parts.append("no intro or outro")
        }
        return parts.joined(separator: ", ")
    }

    /// ".txt, .srt, .vtt, .md, word list on"
    static func transcriptSettings(_ setting: OutputSetting) -> String {
        let formats = TranscriptFormat.allCases.filter(setting.transcriptFormats.contains).map { "." + $0.rawValue }
        return (formats + [setting.applyLexicon ? "word list on" : "word list off"]).joined(separator: ", ")
    }

    static func number(_ n: Int) -> String {
        n.formatted(.number.locale(locale))
    }
}
