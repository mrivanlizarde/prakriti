import Foundation

// The podcast-ready episode (10 Oct): a finished MP3 a person could upload to a podcast host as it
// is, with its tags, artwork, chapters and captions, a text file of the title, show notes and social
// captions, and an upload checklist that measures the file against Apple Podcasts' published rules.
// The quick "Podcast episode" (episode.mp3) stays as it was: engine v0's chain, the draft to listen to.
//
// Why a new chain, measured 10 Oct (docs/BUILD-LOG.md, "Podcast-ready episode"):
// - Episode 1's MP3 rides its volume because loudnorm's second pass falls back to "dynamic": the
//   talk's true peak sits 23.8 dB over its loudness (6 Sep: -23.80 LUFS, +0.04 dBTP), and raising it
//   evenly to -15.4 needs room for 13.9 at most. Riding it, the gain over speech ranged 5.3 to 9.3 dB
//   (5th to 95th percentile), jumped by more than 2 dB within a second for 104 s of the talk, and the
//   room tone in pauses got 9.7 to 13.6 dB, swelling between sentences.
// - This chain levels with a gentle compressor, then raises the whole episode by one even amount
//   (loudnorm reports "linear"), then limits the peaks. Measured on both talks: -16.0 LUFS, true peak
//   -1.3 dBTP, loudness range 3.7 LU (13 Sep, was 4.2) and 4.7 LU (6 Sep, was 5.2).

/// The podcast-ready output's settings: the Outputs screen's, or the recording's own.
struct PodcastReadySettings: Codable, Equatable, Sendable {
    var showName = ""
    var hostName = ""
    var artworkPath: String?
    var explicit = false
    var channels: AudioChannels = .mono
    var bitrateKbps = PodcastMastering.defaultBitrate
    var noiseReduction = false
    /// The intro or outro has a voice made by AI (Apple 1.11 asks for a disclosure).
    var aiVoice = false
    /// How the show numbers its episodes (11 Oct): numbered, an episode without its number is MISSING.
    var numbering: PodcastNumbering = .none
    /// Ivan's closing line for the show notes, in his words, or empty for none (11 Oct). Prakriti never
    /// writes one, and the model never sees it.
    var callToAction = ""

    /// Stereo never goes under 128 kbps (Apple's recommendation for stereo MP3 starts there).
    var bitrate: Int { channels == .stereo ? max(128, bitrateKbps) : bitrateKbps }

    /// The bitrates offered for each layout: Apple recommends 96 to 128 kbps for mono MP3 and 128
    /// to 256 for stereo; 64 kbps mono is inside Apple's range for feeds but measured worse (below).
    static func bitrates(_ channels: AudioChannels) -> [Int] { channels == .mono ? [64, 96, 128] : [128, 192] }
}

/// How the show numbers its episodes, chosen once on the Outputs screen (11 Oct). Apple asks for
/// episode numbers only for a serial show, and season numbers only for a show in seasons.
enum PodcastNumbering: String, Codable, CaseIterable, Sendable {
    case none, episodes, seasons

    var title: String {
        switch self {
        case .none: "Not numbered"
        case .episodes: "Episode numbers"
        case .seasons: "Seasons and episode numbers"
        }
    }

    var needsEpisode: Bool { self != .none }
    var needsSeason: Bool { self == .seasons }
}

/// What the package needs to know about this episode, read from the recording.
struct PodcastEpisodeFacts: Codable, Equatable, Sendable {
    /// Ivan's chosen title and notes (the recording page), or empty when none is chosen yet.
    var title = ""
    var notes = ""
    var episodeNumber: Int?
    var seasonNumber: Int?
    var recordedAt: Date?
    /// "Sun 6 Sep"
    var label = ""
    var kind: RecordingKind = .unknown
    var fileName = ""
}

/// The words that go out with one episode (11 Oct), as `PodcastPackage.copy` works them out: the
/// files and the recording page's Copy buttons both read this, so they always say the same.
struct EpisodeCopy: Equatable, Sendable {
    struct ChapterLine: Equatable, Sendable {
        var label: String
        var title: String
    }

    /// Ivan's title, else the writer's first pick (`titleChosen` false), or nil.
    var title: String?
    var titleChosen = false
    /// Up to three other title options.
    var alternatives: [String] = []
    var oneLine: String?
    /// The show notes' paragraphs: Ivan's, or the writer's draft.
    var notes: [String] = []
    var notesChosen = false
    var aiDisclosure = false
    /// The chapters as written into the finished MP3, at their times in it.
    var chapters: [ChapterLine] = []
    var callToAction: String?
    var keywords: [String] = []
    /// One caption per platform, each with its pull quote.
    var captions: [SocialCaption] = []
    /// The plain captions of a package written before 11 Oct.
    var plainCaptions: [String] = []
    /// What the copy rules left out here, in plain sentences.
    var leftOut: [String] = []

    /// What goes into the host's episode description: the paragraphs, the AI voice line when there is
    /// one, the chapters with their times in the finished file, then the call to action. Nil without notes.
    var showNotes: String? {
        guard !notes.isEmpty else { return nil }
        var parts = [notes.joined(separator: "\n\n")]
        if aiDisclosure { parts.append(PodcastPackage.aiDisclosure) }
        if !chapters.isEmpty { parts.append("Chapters\n" + chapters.map { "\($0.label) \($0.title)" }.joined(separator: "\n")) }
        if let callToAction { parts.append(callToAction) }
        return parts.joined(separator: "\n\n")
    }

    func caption(_ platform: SocialPlatform) -> SocialCaption? { captions.first { $0.platform == platform } }
}

/// Everything a run needs to make the podcast-ready episode.
struct PodcastReadySetup: Sendable {
    var settings = PodcastReadySettings()
    var facts = PodcastEpisodeFacts()
}

/// The podcast-ready mastering chain. Every number was chosen from a measurement on the 13 Sep and 6
/// Sep talks (10 Oct); the reasons are beside them. Two rules from engine v0 hold here too: the
/// limiter keeps `level=disabled`, and the layout and sample rate are set inside the chain, before
/// any limiter.
enum PodcastMastering {
    /// Apple Podcasts: -16 LKFS within 1 dB, true peak not over -1 dBFS (podcasters.apple.com/support/893).
    static let target = -16.0
    static let ceiling = -1.0
    /// 44.1 kHz: inside Apple's recommendation (44.1 or 48 for MP3), and MP3's native rate.
    static let sampleRate = 44_100
    /// 96 kbps mono, measured by a null test against the master (13 Sep): coding noise 18.9 dB under
    /// the speech at 64 kbps, 24.1 at 96, 25.6 at 128, for 29, 43 and 58 MB an hour. 96 is where the
    /// gain stops (1.5 dB more for a third more file), and 64 pushed the true peak to -0.3 dBTP.
    static let defaultBitrate = 96
    /// High-pass at 70 Hz, two poles. The speech spectrum of both talks: 90 to 120 Hz holds a large
    /// share of the voice (-13.6 and -15.2 dB of the whole), 70 to 90 Hz -27 to -30, below 70 Hz -39
    /// to -48 (pops and room). 80 Hz would take about 1.5 dB off the voice's lowest notes; 70 takes
    /// under 1.
    static let highpass = 70.0
    /// The talk is brought to -20 LUFS before the compressor, so its threshold sits in the same place
    /// on every recording, however loud it was recorded.
    static let compressorLevel = -20.0
    /// Gentle: 1.5 to 1 above -22 dB (the middle of the speech), 20 ms attack, 500 ms release.
    /// Measured: the loudness range falls from 6.2 to 3.7 LU (13 Sep) and 6.6 to 4.7 (6 Sep). Stronger
    /// settings (2:1 to 3:1, or a 50 ms attack with a 1 s release) made more gain jumps than engine
    /// v0's riding (up to 123 s over 2 dB a second on 6 Sep, against v0's 104 and this one's 85).
    static let threshold = -22.0
    static let ratio = 1.5
    static let attack = 20.0
    static let release = 500.0
    static let knee = 2.82843
    /// Light noise reduction, off unless chosen. Measured: the room tone sits 38 dB under the speech
    /// on 13 Sep and 51 dB on 6 Sep, and afftdn at 6 or 12 dB lowered it by only 1.5 dB, so it is
    /// not worth the risk of smearing the voice on these rooms. On for a noisier room only.
    static let noiseReduction = "afftdn=nr=6:tn=1"
    /// The sample-peak limits before and after the even raise. alimiter limits samples, not true
    /// peaks: measured, the true peak lands 1.2 to 1.8 dB over its limit once encoded (13 Sep -1.4
    /// dBTP and 6 Sep -1.2 at -2.8; the 6 Sep talk trimmed by 10 s reached -0.98, over the line). So
    /// -3.0, and a true peak over -1.1 makes the MP3 once more with both limits lowered by the excess.
    /// The last limiter sits 0.3 dB higher so it only catches what the even raise lifts; when it had to
    /// work hard (0.7 dB), the true peak rose instead.
    static let preLimit = -3.0
    static let finalLimit = -2.7
    /// The true peak a finished MP3 must be at or under before it is kept: 0.1 dB inside Apple's -1, so
    /// a meter that rounds to one decimal can never show a pass for a file that is over.
    static let peakAim = -1.1
    /// LAME at 96 or 128 kbps measures 0.4 LU quieter than the master it encodes (13 Sep: the master
    /// -16.0, the MP3 -16.4), so the master aims 0.4 LU louder.
    static let encoderAllowance = 0.4
    /// The even raise is linear only if the peaks fit, so the gain before the limiter is found by
    /// measuring until loudnorm's own correction is under this.
    static let gainTolerance = 0.2

    static func number(_ value: Double) -> String { Mastering.number(value) }
    static func linear(_ db: Double) -> String { String(format: "%.4f", pow(10, db / 20)) }

    static func layout(_ channels: AudioChannels) -> String {
        "aformat=channel_layouts=\(channels.rawValue),aresample=\(sampleRate)"
    }

    /// The talk's own processing, after the trim, cuts and the layout at 48 kHz: high-pass, optional
    /// noise reduction, the talk brought to -20 LUFS, the compressor, then the layout at 44.1 kHz.
    static func talkChain(pregain: Double, channels: AudioChannels, noiseReduction reduce: Bool) -> String {
        var chain = "highpass=f=\(number(highpass)):poles=2"
        if reduce { chain += "," + noiseReduction }
        chain += ",volume=\(number(pregain))dB"
        chain += ",acompressor=threshold=\(number(threshold))dB:ratio=\(number(ratio)):attack=\(number(attack)):release=\(number(release)):knee=\(knee):detection=rms:makeup=1"
        chain += "," + layout(channels)
        return chain
    }

    /// The gain before the first limiter.
    static func gainStage(_ gain: Double, preLimit: Double = preLimit) -> String {
        "volume=\(number(gain))dB,alimiter=limit=\(linear(preLimit)):level=disabled:attack=5:release=50"
    }

    static func measure() -> String {
        "loudnorm=I=\(number(target)):TP=\(number(ceiling)):LRA=11:print_format=json"
    }

    /// loudnorm's second pass in linear mode with the first pass's numbers, then the layout and rate
    /// again (a no-op, kept so nothing can resample after the limiter), then the last limiter.
    static func finish(measured m: Measure.LoudnormPass, allowance: Double, channels: AudioChannels, finalLimit: Double = finalLimit) -> String {
        "loudnorm=I=\(number(target + allowance)):TP=\(number(ceiling)):LRA=11:"
            + "measured_I=\(m.inputI):measured_TP=\(m.inputTP):measured_LRA=\(m.inputLRA):measured_thresh=\(m.inputThresh):"
            + "offset=\(m.targetOffset):linear=true:print_format=json,"
            + "aformat=sample_rates=\(sampleRate):channel_layouts=\(channels.rawValue),"
            + "alimiter=limit=\(linear(finalLimit)):level=disabled:attack=5:release=50"
    }

    /// The pregain that brings a talk measured at `lufs` to the compressor's level.
    static func pregain(talk lufs: Double) -> Double { max(-30, min(30, compressorLevel - lufs)) }

    /// The ffmpeg inputs and filter for the program: the processed talk (a float WAV) with the intro
    /// and outro, each at the talk's loudness, joined end to end, then `tail`.
    static func program(talk: String, intro: Mastering.Piece?, outro: Mastering.Piece?, channels: AudioChannels, tail: String) -> [String] {
        guard intro != nil || outro != nil else { return ["-i", talk, "-af", tail] }
        var inputs: [String] = []
        var graph: [String] = []
        var labels: [String] = []
        func add(_ path: String, _ chain: String, _ label: String) {
            graph.append("[\(labels.count):a]\(chain)[\(label)]")
            inputs += ["-i", path]
            labels.append("[\(label)]")
        }
        if let intro { add(intro.path, "\(layout(channels)),volume=\(number(intro.gainDB))dB", "intro") }
        add(talk, "anull", "talk")
        if let outro { add(outro.path, "\(layout(channels)),volume=\(number(outro.gainDB))dB", "outro") }
        graph.append(labels.joined() + "concat=n=\(labels.count):v=0:a=1,\(tail)[out]")
        return inputs + ["-filter_complex", graph.joined(separator: ";"), "-map", "[out]"]
    }
}

/// One line of the upload checklist.
struct ChecklistLine: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case pass = "PASS", missing = "MISSING", fail = "FAIL"
    }
    var status: Status
    var item: String
    var detail: String
    /// What to do, for a line that does not pass.
    var todo: String?

    var text: String {
        let pad = String(repeating: " ", count: max(1, 9 - status.rawValue.count))
        return status.rawValue + pad + item + ": " + detail + (todo.map { " What to do: " + $0 } ?? "")
    }
}

/// What a podcast-ready make measured and wrote, kept on the recording (as JSON) and shown on its page.
struct PodcastReadyRecord: Codable, Equatable, Sendable {
    var fileName: String
    var integratedLUFS: Double
    var truePeak: Double
    var loudnessRange: Double
    var normalizationType: String
    var sampleRate: Int
    var bitrateKbps: Int
    var channels: Int
    var duration: Double
    /// The intro, the kept talk and the outro end to end: what the length must be.
    var expectedDuration: Double?
    var bytes: Int64
    /// The talk as recorded, before the chain (loudnorm's measure), and its loudness range.
    var talkLUFS: Double?
    var talkLRA: Double?
    /// The limits were lowered once because the first MP3's true peak was over the ceiling.
    var corrected: Bool = false
    var captions: Int = 0
    var chapters: Int = 0
    var checklist: [ChecklistLine]
    var madeAt: Date
    /// The title, notes and settings the files were made with, to tell when they are out of date.
    var fingerprint: String
    /// Every file the make left in the Podcast-ready folder, with its size (11 Oct). Optional so a
    /// record made before still reads.
    var files: [PackageFile]?

    struct PackageFile: Codable, Equatable, Sendable {
        var name: String
        var bytes: Int64
    }

    var passed: Int { checklist.filter { $0.status == .pass }.count }
    var missing: Int { checklist.filter { $0.status == .missing }.count }
    var failed: Int { checklist.filter { $0.status == .fail }.count }

    /// "2 missing, 1 failed" or "Every line passes".
    var summary: String {
        var parts: [String] = []
        if failed > 0 { parts.append("\(failed) failed") }
        if missing > 0 { parts.append("\(missing) missing") }
        return parts.isEmpty ? "Every line passes" : parts.joined(separator: ", ") + ", \(passed) passed"
    }

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String?) -> PodcastReadyRecord? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PodcastReadyRecord.self, from: data)
    }
}

/// The package: names, chapters, the text file and the checklist. Pure functions, tested; the run
/// that measures and writes them is `Pipeline.packagePodcastReady`.
enum PodcastPackage {
    static let folderName = "Podcast-ready"
    static let checklistName = "Upload checklist.txt"
    /// The episode's words, plain text to paste from, and the same as Markdown (11 Oct).
    static let textName = "Episode text.txt"
    static let markdownName = "Episode text.md"

    /// Why a recording is never made ready to upload, or nil. A class: students may be heard, and
    /// Prakriti cannot check voices yet (SCOPE PRV, the standing rule that classes are not published).
    static func refusal(kind: RecordingKind) -> String? {
        kind == .lesson ? "This is a class. Students may be heard in a class, so it is never made ready to upload." : nil
    }
    /// Apple's published requirements, read 10 Oct 2026, named in the checklist.
    static let sources = "Apple Podcasts' audio requirements (podcasters.apple.com/support/893) and show cover rules (support/5514), read 10 Oct 2026"

    /// "2026-09-06": the date a file is named by until it has a title.
    static func isoDate(_ date: Date?) -> String {
        guard let date else { return "undated" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func year(_ date: Date?) -> String? {
        guard let date else { return nil }
        return String(Calendar(identifier: .gregorian).component(.year, from: date))
    }

    /// A file name that is safe on every system a host might run: ASCII only (Apple asks for ASCII
    /// file names and addresses, research 06 §3.3; "Mārga" becomes "Marga"), no slashes, colons or
    /// other reserved characters, no dashes Ivan's rule forbids, runs of spaces made one, at most 120
    /// characters, never starting or ending with a dot or space.
    static func safe(_ text: String) -> String {
        var s = text.precomposedStringWithCanonicalMapping
        s = s.replacingOccurrences(of: "\u{2014}", with: ", ").replacingOccurrences(of: "\u{2013}", with: "-")
        s = s.replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
        s = s.applyingTransform(.toLatin, reverse: false) ?? s
        s = s.applyingTransform(.stripDiacritics, reverse: false) ?? s
        s = String(s.unicodeScalars.filter(\.isASCII).map(Character.init))
        let reserved = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters).union(.newlines)
        s = String(s.unicodeScalars.map { reserved.contains($0) ? " " : Character($0) })
        s = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces))
        if s.count > 120 { s = String(s.prefix(120)).trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespaces)) }
        return s
    }

    /// "<Show name> - <Episode title>", or the date in place of a title not chosen yet.
    static func baseName(settings: PodcastReadySettings, facts: PodcastEpisodeFacts) -> String {
        let title = safe(facts.title)
        let show = safe(settings.showName)
        let episode = title.isEmpty ? isoDate(facts.recordedAt) : title
        let name = show.isEmpty ? episode : show + " - " + episode
        return safe(name).isEmpty ? "episode" : safe(name)
    }

    /// The chapters to write, from the writer's chapters on the episode's clock: the first moved to
    /// 0:00 (it covers any intro), each ending where the next starts, the last at the end. Nil with
    /// the reason when they cannot be written: none, fewer than three, or not in order.
    static func chapters(_ written: [WrittenChapter], duration: Double) -> (chapters: [ID3.Chapter], problem: String?) {
        guard !written.isEmpty else { return ([], nil) }
        let sorted = written.sorted { $0.start < $1.start }
        guard sorted.count >= 3 else {
            return ([], "Only \(Format.count(sorted.count, "chapter")); a chapter list needs at least 3, so none were written into the file.")
        }
        var out: [ID3.Chapter] = []
        let endMS = UInt32(max(0, duration * 1000).rounded(.down))
        for (index, chapter) in sorted.enumerated() {
            let start = index == 0 ? 0 : UInt32(max(0, chapter.start * 1000).rounded())
            if let last = out.last, start <= last.startMS {
                return ([], "Chapter \(index + 1) does not start after the one before it, so none were written into the file.")
            }
            if start >= endMS { return ([], "Chapter \(index + 1) starts after the end of the episode, so none were written into the file.") }
            out.append(ID3.Chapter(id: "ch\(index)", startMS: start, endMS: endMS, title: chapter.title))
        }
        for index in out.indices.dropLast() { out[index].endMS = out[index + 1].startMS }
        return (out, nil)
    }

    /// Checks chapters read back from a file: in order, the first at 0, each ending where the next
    /// starts, the last at the end, a table of contents listing them all. Nil when they pass.
    static func chapterProblem(_ tag: ID3.Tag, duration: Double) -> String? {
        let chapters = tag.chapters
        guard chapters.count >= 3 else { return "the file holds \(Format.count(chapters.count, "chapter")), under 3" }
        guard chapters.first?.startMS == 0 else { return "the first chapter does not start at 0:00" }
        for (a, b) in zip(chapters, chapters.dropFirst()) where !(b.startMS > a.startMS && a.endMS == b.startMS) {
            return "chapter \"\(b.title)\" does not follow the one before it"
        }
        if let last = chapters.last, abs(Double(last.endMS) / 1000 - duration) > 1 { return "the last chapter does not end at the end of the episode" }
        guard chapters.allSatisfy({ !$0.title.isEmpty }) else { return "a chapter has no title" }
        guard let toc = tag.toc, toc.topLevel, toc.ordered, toc.children == chapters.map(\.id) else {
            return "the table of contents does not list the chapters in order"
        }
        return nil
    }

    /// "#YogaMarga #Pranayama": hashtags made from the tags, letters and digits only.
    static func hashtags(_ tags: [String]) -> String {
        tags.compactMap(WritingCheck.hashtag).map { "#" + $0 }.joined(separator: " ")
    }

    /// The show notes the package uses: Ivan's own (chosen on the page), else the writer's draft.
    static func showNotes(facts: PodcastEpisodeFacts, written: WrittenPackage?) -> (text: String, chosen: Bool)? {
        let own = facts.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !own.isEmpty { return (own, true) }
        if let draft = written?.showNotes.trimmingCharacters(in: .whitespacesAndNewlines), !draft.isEmpty { return (draft, false) }
        return nil
    }

    static let aiDisclosure = "This episode's intro or outro uses an AI-generated voice."

    /// The MP3's comment: the one-line summary, else the summary, else the show notes' first sentence.
    static func comment(facts: PodcastEpisodeFacts, written: WrittenPackage?) -> String? {
        if let line = written?.oneLine?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty, CopyRules.flag(line) == nil { return line }
        if let summary = written?.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            let screened = CopyRules.withoutFlaggedSentences(summary).text
            if !screened.isEmpty { return screened }
        }
        guard let notes = showNotes(facts: facts, written: written)?.text else { return nil }
        return CopyRules.sentences(notes).first ?? notes
    }

    /// The episode's words, worked out once for "Episode text.txt", "Episode text.md" and the Copy
    /// buttons on the recording's page, so what is copied is what the file says. The writer's drafts
    /// are read through the copy rules again here (a package written before 11 Oct never was); Ivan's
    /// own title, notes and call to action are his words and are never changed, except that a dash
    /// his rule forbids becomes a comma.
    static func copy(settings: PodcastReadySettings, facts: PodcastEpisodeFacts, written: WrittenPackage?, chapters: [ID3.Chapter]) -> EpisodeCopy {
        var c = EpisodeCopy()
        var leftOut: [String] = []
        func screened(_ text: String, _ what: String) -> String? {
            if let why = CopyRules.flag(text) {
                leftOut.append("The \(what) named \(why), so it is left out here.")
                return nil
            }
            return text
        }

        // The title: Ivan's, else the writer's first pick; then up to three alternatives.
        let own = facts.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let drafts = (written?.titles ?? []).compactMap { screened($0, "title \"\($0)\"") }
        if !own.isEmpty && !isOnlyADate(own) {
            c.title = WritingText.withoutDashes(own).0
            c.titleChosen = true
            c.alternatives = Array(drafts.filter { $0.caseInsensitiveCompare(own) != .orderedSame }.prefix(3))
        } else if let first = drafts.first {
            c.title = first
            c.alternatives = Array(drafts.dropFirst().prefix(3))
        }

        // The one-line summary, else the first sentence of the summary when it fits.
        if let line = written?.oneLine, !line.isEmpty {
            c.oneLine = screened(line, "one-line summary")
        } else if let first = written?.summary.flatMap({ CopyRules.sentences($0).first }), first.count <= WritingCheck.oneLineLimit {
            c.oneLine = screened(first, "summary's first sentence")
        }

        // The show notes: Ivan's as written, or the draft with any sentence the rules forbid taken out.
        if let notes = showNotes(facts: facts, written: written) {
            c.notesChosen = notes.chosen
            if notes.chosen {
                c.notes = CopyRules.paragraphs(WritingText.withoutDashes(notes.text).0)
            } else {
                let checked = CopyRules.withoutFlaggedSentences(notes.text)
                c.notes = CopyRules.paragraphs(checked.text)
                for why in checked.removed { leftOut.append("A sentence of the drafted show notes named \(why), so it is left out here.") }
            }
        }
        c.aiDisclosure = settings.aiVoice
        c.chapters = chapters.map { EpisodeCopy.ChapterLine(label: WritingText.stamp(Double($0.startMS) / 1000), title: $0.title) }
        let action = WritingText.withoutDashes(settings.callToAction.trimmingCharacters(in: .whitespacesAndNewlines)).0
        c.callToAction = action.isEmpty ? nil : action

        // Keywords, else the tags of a package written before keywords.
        c.keywords = (written?.keywords ?? written?.tags ?? []).compactMap { screened($0, "keyword \"\($0)\"") }

        // One caption per platform, each with its pull quote; or the plain captions written before.
        for var caption in written?.social ?? [] {
            guard screened(caption.text, "\(caption.platform.title) caption") != nil else { continue }
            if let quote = caption.pullQuote, screened(quote, "\(caption.platform.title) pull quote") == nil {
                caption.pullQuote = nil
                caption.pullQuoteAt = nil
            }
            caption.hashtags = caption.hashtags.filter { CopyRules.flag($0) == nil }
            c.captions.append(caption)
        }
        if written?.social == nil {
            c.plainCaptions = (written?.captions ?? []).enumerated().compactMap { screened($0.element, "caption \($0.offset + 1)") }
        }
        c.leftOut = leftOut
        return c
    }

    /// "Episode text.txt" (plain text, to paste from) or "Episode text.md" (the same, as Markdown):
    /// the title and its alternatives, the one-line summary, the show notes with the chapters of the
    /// finished file and the call to action, the keywords, a caption for Instagram, LinkedIn and X and
    /// Threads each with its pull quote, the details for the host's form, and what the checks left
    /// out. Every draft is said to be a draft; nothing is posted.
    static func episodeText(_ c: EpisodeCopy, settings: PodcastReadySettings, facts: PodcastEpisodeFacts, written: WrittenPackage?,
                            fileName: String, madeAt: Date, markdown md: Bool) -> String {
        var t = ""
        func heading(_ text: String) { t += md ? "\n## \(text)\n\n" : "\n\(text.uppercased())\n" }
        func subheading(_ text: String) { t += md ? "\n### \(text)\n\n" : "\n\(text)\n" }
        func line(_ text: String) { t += text + "\n" }
        func aside(_ text: String) { t += (md ? "_(\(text))_" : "(\(text))") + "\n" }
        /// A line that starts with # is a heading in Markdown; hashtags keep their sign.
        func escaped(_ text: String) -> String { md ? text.replacingOccurrences(of: "#", with: "\\#") : text }

        t += md ? "# \(facts.label): episode text\n\n" : "\(facts.label): episode text\n\n"
        let by = written.map { "Drafted on this Mac by \($0.writtenBy) and checked against the transcript: every pull quote below was found word for word in it, and every chapter time is in the finished file. " } ?? ""
        line("For \"\(fileName)\" in this folder, made by Prakriti on \(Format.dayAndTime(madeAt)). " + by
             + "Nothing has been posted or uploaded. Read every line against the episode before using it.")

        heading("Episode title")
        if let title = c.title {
            line(md ? "**\(title)**" : title)
            if !c.titleChosen { aside("Not chosen yet: this is the writer's first pick. Use This Title on the recording's page makes it the episode's title and the file's name.") }
            if !c.alternatives.isEmpty {
                subheading("Alternatives")
                for (index, option) in c.alternatives.enumerated() { line("\(index + 1). \(option)") }
            }
        } else {
            line("Not chosen yet. Write one in About this recording, on the recording's page.")
        }

        heading("One-line summary")
        if let one = c.oneLine {
            line(one)
            aside("\(one.count) characters. Written into the MP3 as its comment.")
        } else {
            line("None yet. It is written with the titles and show notes.")
        }

        heading("Show notes")
        if c.notes.isEmpty {
            line("None yet. Turn on Titles, show notes and chapters for this recording, or write notes in its Info.")
        }
        if let block = c.showNotes {
            if md {
                for paragraph in c.notes { t += paragraph + "\n\n" }
                if c.aiDisclosure { t += aiDisclosure + "\n\n" }
                if !c.chapters.isEmpty {
                    t += "Chapters\n\n" + c.chapters.map { "- \($0.label) \($0.title)" }.joined(separator: "\n") + "\n\n"
                }
                if let action = c.callToAction { t += action + "\n\n" }
            } else {
                t += block + "\n\n"
            }
            var said: [String] = []
            if !c.notes.isEmpty {
                said.append(c.notesChosen ? "Your notes, as written on the recording's page."
                    : "A draft by \(written?.writtenBy ?? "the writing model"), not chosen yet. Press Use as Notes on the recording's page, or write your own.")
            }
            said.append(c.chapters.isEmpty ? "No chapters are in the file." : "The chapters are the ones written into the MP3, at their times in this file.")
            said.append(c.callToAction == nil ? "No call to action is set (Outputs screen, Podcast-ready episode), so none closes the notes." : "The last line is your call to action, from the Outputs screen.")
            aside(said.joined(separator: " "))
        }

        heading("Keywords")
        line(c.keywords.isEmpty ? "None yet." : c.keywords.joined(separator: ", "))

        heading("Social captions")
        line("Drafts to post by hand. Nothing is posted. Each pull quote is the teacher's own words, found word for word in one line of the transcript, with its time in this file.")
        if !c.captions.isEmpty {
            for caption in c.captions {
                let count = caption.platform == .x ? "\(caption.text.count) of \(caption.platform.limit) characters" : Format.count(caption.text.count, "character")
                subheading("\(caption.platform.title) (\(count))")
                line(caption.text)
                if !caption.hashtags.isEmpty { t += "\n" + escaped(caption.hashtags.map { "#" + $0 }.joined(separator: " ")) + "\n" }
                if let quote = caption.pullQuote {
                    let at = caption.pullQuoteAt.map { ", at \(WritingText.stamp($0))" } ?? ""
                    t += md ? "\n> \u{201C}\(quote)\u{201D}\n>\n> Pull quote\(at)\n" : "\nPull quote\(at): \"\(quote)\"\n"
                } else {
                    t += "\n" + (md ? "_(No pull quote: none was found word for word in the transcript.)_" : "(No pull quote: none was found word for word in the transcript.)") + "\n"
                }
            }
            let missing = SocialPlatform.allCases.filter { platform in !c.captions.contains { $0.platform == platform } }
            if !missing.isEmpty { aside("No caption for \(missing.map(\.title).joined(separator: " or ")): it broke a check, named at the end of this file.") }
        } else if !c.plainCaptions.isEmpty {
            aside("Written before the captions were made per platform: write them again for Instagram, LinkedIn and X and Threads, each with a pull quote.")
            for (index, caption) in c.plainCaptions.enumerated() { line("\(index + 1). \(caption)") }
        } else {
            line("None yet. They are written with the titles and show notes.")
        }

        heading("For the host's form")
        line((md ? "- " : "") + "Show: " + (settings.showName.isEmpty ? "not set (Outputs screen, Podcast-ready episode)" : settings.showName))
        line((md ? "- " : "") + "Host or author: " + (settings.hostName.isEmpty ? "not set" : settings.hostName))
        line((md ? "- " : "") + "Episode number: " + (facts.episodeNumber.map(String.init) ?? (settings.numbering.needsEpisode ? "not set, and the show is numbered" : "not set (the show is not numbered)")))
        line((md ? "- " : "") + "Season: " + (facts.seasonNumber.map(String.init) ?? (settings.numbering.needsSeason ? "not set, and the show has seasons" : "not set")))
        line((md ? "- " : "") + "Explicit: " + (settings.explicit ? "Yes" : "No"))

        var checks = c.leftOut
        if let left = written?.leftOutPullQuotes, !left.isEmpty {
            checks.append("\(Format.count(left.count, "pull quote")) the writer gave \(left.count == 1 ? "was" : "were") not one line of the transcript word for word, so \(left.count == 1 ? "it was" : "they were") left out.")
        }
        for note in written?.notes ?? [] where note.contains("caption") || note.contains("pull quote") || note.contains("one-line") || note.contains("show notes") || note.contains("title") || note.contains("keyword") {
            checks.append(note)
        }
        if !checks.isEmpty {
            heading("What the checks changed or left out")
            for check in checks { line((md ? "- " : "- ") + check) }
        }
        return t
    }

    /// What the checklist reads from the finished file.
    struct Measured: Sendable {
        var lufs: Double
        var truePeak: Double
        var lra: Double
        var normalizationType: String
        var sampleRate: Int?
        var bitrateKbps: Int?
        var channels: Int?
        var duration: Double?
        var expectedDuration: Double
        var bytes: Int64
        var tailDecodes: Bool
        var tag: ID3.Tag?
        /// The tag fields Prakriti meant to write, by frame id.
        var intended: [String]
        var artwork: ArtworkCheck?
        var chapterProblem: String?
        var chaptersWritten: Int
        var captions: (count: Int, first: Double, lastEnd: Double)?
        var captionsProblem: String?
    }

    /// The upload checklist, line by line: each measured or read back from the file, PASS, MISSING
    /// or FAIL, with what to do. Show name and artwork are MISSING until Ivan sets them; Prakriti
    /// never invents either.
    static func checklist(_ m: Measured, settings: PodcastReadySettings, facts: PodcastEpisodeFacts, written: WrittenPackage?) -> [ChecklistLine] {
        var lines: [ChecklistLine] = []
        func add(_ status: ChecklistLine.Status, _ item: String, _ detail: String, _ todo: String? = nil) {
            lines.append(ChecklistLine(status: status, item: item, detail: detail, todo: status == .pass ? nil : todo))
        }
        // The sound.
        let loud = abs(m.lufs - PodcastMastering.target) <= 1.0
        add(loud ? .pass : .fail, "Loudness", String(format: "%.2f LUFS integrated. Apple asks for -16, within 1.", m.lufs),
            "Make it again; if it still misses, the recording needs a look.")
        add(m.truePeak <= PodcastMastering.ceiling ? .pass : .fail, "True peak",
            String(format: "%.2f dBTP, measured to the hundredth. Apple asks for -1 or lower.", m.truePeak), "Make it again; Prakriti lowers the limiter when a peak is over.")
        add(m.normalizationType == "linear" ? .pass : .fail, "Leveling",
            m.normalizationType == "linear" ? "Raised evenly, one amount for the whole episode (loudnorm reports linear)."
                : "Leveled moment to moment (loudnorm reports \(m.normalizationType)), which rides the volume up and down.",
            "Make it again and say so if it repeats.")
        add(.pass, "Loudness range", String(format: "%.1f LU, after a gentle compressor. Apple sets no limit; it is for comfort in a car or on a walk.", m.lra))
        if let rate = m.sampleRate {
            add(rate == 44_100 || rate == 48_000 ? .pass : .fail, "Sample rate", "\(String(format: "%.1f", Double(rate) / 1000)) kHz. Apple takes 44.1 or 48.", "Make it again.")
        } else {
            add(.fail, "Sample rate", "Could not be read.", "Make it again.")
        }
        if let kbps = m.bitrateKbps, let ch = m.channels {
            let mono = ch == 1
            let ok = mono ? (64...128).contains(kbps) : (128...256).contains(kbps)
            add(ok ? .pass : .fail, "Bitrate", "\(kbps) kbps \(mono ? "mono" : "stereo") MP3. Apple recommends \(mono ? "96 to 128 kbps for mono" : "128 to 256 kbps for stereo") (and takes MP3 or AAC).",
                "Choose \(mono ? "96" : "128") kbps on the Outputs screen and make it again.")
        } else {
            add(.fail, "Bitrate", "Could not be read.", "Make it again.")
        }
        if let duration = m.duration {
            let ok = abs(duration - m.expectedDuration) <= 1
            add(ok ? .pass : .fail, "Length", "\(Format.timecode(duration))" + (ok ? ", the length it should be (within 1 s of what was kept, with any intro and outro)." : String(format: ", but %.1f s was expected.", m.expectedDuration)),
                "Make it again; the file cannot be trusted.")
        } else {
            add(.fail, "Length", "Could not be read.", "Make it again.")
        }
        add(.pass, "File size", "\(Format.megabytes(m.bytes)).")
        add(m.tailDecodes ? .pass : .fail, "Plays to the end", m.tailDecodes ? "Its last 5 seconds decode." : "Its last 5 seconds do not decode.", "Make it again.")

        // What it is called, and by whom.
        add(settings.showName.isEmpty ? .missing : .pass, "Show name",
            settings.showName.isEmpty ? "Not set. Prakriti never makes one up." : "\"\(settings.showName)\", in the MP3 as its album.",
            "Type it on the Outputs screen, Podcast-ready episode, then Update Podcast-Ready Files on the recording's page.")
        let title = facts.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || isOnlyADate(title) {
            add(.missing, "Episode title", title.isEmpty ? "Not chosen; the file is named by its date." : "\"\(title)\" is only a date.",
                (written?.titles.isEmpty == false ? "Pick one of the drafts in \"\(textName)\" with Use This Title" : "Write one in About this recording")
                    + " on the recording's page, then Update Podcast-Ready Files.")
        } else {
            add(.pass, "Episode title", "\"\(title)\".")
        }
        add(settings.hostName.isEmpty ? .missing : .pass, "Host or author", settings.hostName.isEmpty ? "Not set." : "\"\(settings.hostName)\", in the MP3 as its artist.",
            "Type it on the Outputs screen, Podcast-ready episode.")
        // Numbers, as the show is numbered on the Outputs screen (11 Oct): a numbered show needs each
        // episode's number, and a show in seasons its season too; otherwise they are optional.
        let numbers = [facts.episodeNumber.map { "episode \($0)" }, facts.seasonNumber.map { "season \($0)" }].compactMap { $0 }
        let lacking = [settings.numbering.needsEpisode && facts.episodeNumber == nil ? "the episode number" : nil,
                       settings.numbering.needsSeason && facts.seasonNumber == nil ? "the season" : nil].compactMap { $0 }
        if !lacking.isEmpty {
            add(.missing, "Episode and season numbers", "The show is set to \(settings.numbering.title.lowercased()) (Outputs screen), and \(lacking.joined(separator: " and ")) \(lacking.count == 1 ? "is" : "are") not set.",
                "Type \(lacking.joined(separator: " and ")) on the recording's page, then Update Podcast-Ready Files.")
        } else if settings.numbering == .none {
            add(.pass, "Episode and season numbers", numbers.isEmpty ? "Not numbered, as set on the Outputs screen. Apple asks for numbers only for a serial show."
                : numbers.joined(separator: ", ").capitalizedFirst + ", written into the MP3, though the show is set to not numbered.")
        } else {
            add(.pass, "Episode and season numbers", numbers.joined(separator: ", ").capitalizedFirst + ", as the show is numbered.")
        }
        add(.pass, "Explicit", settings.explicit ? "Yes, as set on the Outputs screen." : "No, as set on the Outputs screen. Choose Yes there if anything said needs it.")

        // The tag, read back.
        if let tag = m.tag {
            let names = ["TIT2": "title", "TPE1": "author", "TALB": "show", "TDRC": "year", "COMM": "comment", "TCON": "genre", "TRCK": "episode number", "APIC": "artwork", "CTOC": "chapters"]
            let missing = m.intended.filter { !tag.frameIDs.contains($0) }
            let genreOK = tag.text["TCON"] == "Podcast"
            let order = ["TIT2", "TPE1", "TALB", "TDRC", "COMM", "TCON", "TRCK", "APIC", "CTOC"]
            let read = order.filter { m.intended.contains($0) && tag.frameIDs.contains($0) }.compactMap { $0 == "TCON" && genreOK ? "genre Podcast" : names[$0] }
            add(missing.isEmpty && genreOK && tag.version == 4 ? .pass : .fail, "Tags",
                missing.isEmpty ? "ID3v2.\(tag.version), read back from the file: \(read.joined(separator: ", "))."
                    : "Written but not read back: \(missing.compactMap { names[$0] }.joined(separator: ", ")).",
                "Update Podcast-Ready Files; if it repeats, the file cannot be trusted.")
        } else {
            add(.fail, "Tags", "No ID3 tag could be read from the file.", "Update Podcast-Ready Files.")
        }

        // Artwork.
        if let art = m.artwork {
            if art.passes, let picture = m.tag?.picture {
                add(.pass, "Artwork", "\(art.fileName): \(art.line). Square, \(ArtworkCheck.smallest) to \(ArtworkCheck.largest) px, \(art.format ?? ""), RGB, no transparency; in the MP3 (\(Format.kilobytes(Int64(picture.bytes))), read back).")
            } else if art.passes {
                add(.fail, "Artwork", "\(art.fileName) passes Apple's rules but is not in the MP3.", "Update Podcast-Ready Files.")
            } else {
                add(.fail, "Artwork", "\(art.fileName): \(art.problems.joined(separator: " ")) It was not put in the MP3.",
                    "Fix the image or choose another on the Outputs screen.")
            }
        } else {
            add(.missing, "Artwork", "None chosen. Prakriti never makes artwork.",
                "Choose the show's artwork on the Outputs screen (square JPEG or PNG, 1400 to 3000 px, RGB, under 512 KB). Hosts also ask for it once, on the show.")
        }

        // Chapters.
        if m.chaptersWritten > 0 {
            if let problem = m.chapterProblem {
                add(.fail, "Chapters", "Read back from the file, but \(problem).", "Write the titles and chapters again.")
            } else {
                add(.pass, "Chapters", "\(m.chaptersWritten) chapters, read back from the file: the first at 0:00, each after the one before, listed in a table of contents.")
            }
        } else if let problem = m.chapterProblem {
            add(.fail, "Chapters", problem, "Write the titles and chapters again.")
        } else {
            add(.missing, "Chapters", "None. They are written with the titles and show notes.",
                "Turn on Titles, show notes and chapters for this recording, or press Write Titles and Notes in its Outputs.")
        }

        // Captions (the transcript timed to this file).
        if let c = m.captions {
            add(m.captionsProblem == nil ? .pass : .fail, "Transcript",
                m.captionsProblem ?? "\(Format.count(c.count, "caption")) in .srt and .vtt, timed to this file: the first at \(Format.timecode(c.first)), the last ending at \(Format.timecode(c.lastEnd)) of \(Format.timecode(m.duration ?? 0)).",
                "Make it again.")
        } else {
            add(.missing, "Transcript", "No .srt or .vtt: the transcript is turned off for this recording.", "Turn the transcript on and make it again.")
        }

        // The words around it.
        let title2 = written?.writtenBy ?? "the writing model"
        let episode = Self.copy(settings: settings, facts: facts, written: written, chapters: [])
        let closing = episode.callToAction == nil ? " No call to action is set (optional)." : " Your call to action closes them."
        if let notes = showNotes(facts: facts, written: written) {
            add(notes.chosen ? .pass : .missing, "Show notes",
                (notes.chosen ? "Yours, from the recording's page (\(WritingText.words(notes.text)) words), in \"\(textName)\" with the chapters." : "A draft by \(title2) is in \"\(textName)\", not chosen yet.") + closing,
                "Read the draft, then press Use as Notes on the recording's page (or write your own), then Update Podcast-Ready Files.")
        } else {
            add(.missing, "Show notes", "None.", "Turn on Titles, show notes and chapters, or write notes on the recording's page.")
        }
        if !episode.captions.isEmpty {
            let quotes = episode.captions.filter { $0.pullQuote != nil }.count
            let complete = episode.captions.count == SocialPlatform.allCases.count && quotes == episode.captions.count
            add(complete ? .pass : .missing, "Social captions",
                "\(episode.captions.map(\.platform.title).joined(separator: ", ")), with \(Format.count(quotes, "pull quote")) found word for word in the transcript, in \"\(textName)\", to post by hand.",
                "Write the titles and notes again for the missing ones, or write them yourself.")
        } else if !episode.plainCaptions.isEmpty {
            add(.missing, "Social captions", "\(Format.count(episode.plainCaptions.count, "draft")) written before captions were made per platform, with no pull quotes.",
                "Press Write Again on the recording's page for a caption per platform, each with its pull quote.")
        } else {
            add(.missing, "Social captions", "None yet.", "They are written with the titles and show notes.")
        }
        if written != nil {
            add(.pass, "Copy rules", episode.leftOut.isEmpty
                ? "The drafts in \"\(textName)\" name no prices, money, earnings, enrollment or offers, checked sentence by sentence. Your own title, notes and call to action are yours and are not changed."
                : "\(Format.count(episode.leftOut.count, "drafted sentence or caption", "drafted sentences or captions")) named prices, money, earnings, enrollment or an offer and \(episode.leftOut.count == 1 ? "is" : "are") left out of \"\(textName)\"; the rest were checked sentence by sentence.")
        }

        // Rules about people.
        if settings.aiVoice {
            add(.missing, "AI voice (Apple 1.11)", "You said the intro or outro uses an AI-made voice. Prakriti added a line saying so to the show notes text.",
                "Apple asks for it to be said in the audio too: make sure the intro or outro says it, and keep the line in the show notes.")
        } else {
            add(.pass, "AI voice (Apple 1.11)", "No AI-made voice in the episode (none is used unless you choose one on the Outputs screen).")
        }
        switch facts.kind {
        case .talk: add(.pass, "What this is", "A talk, one teacher speaking, as you marked it. Not a class.")
        case .lesson: add(.fail, "What this is", "A class: students may be heard. A class is never uploaded.", "Do not upload it.")
        case .conversation: add(.fail, "What this is", "A conversation: more than one person speaks, and Prakriti cannot check who.", "Do not upload it until speakers can be checked.")
        case .unknown, .test: add(.missing, "What this is", "Not set. Unknown voices count as students.",
                                  "On the recording's page, mark it as a talk with one teacher speaking, if it is one.")
        }
        add(.missing, "Speakers", "Not checked by Prakriti: it cannot tell voices apart yet.",
            "Listen for any voice other than the teacher's, and any name said, before uploading. Approve on the recording's page records your word.")
        return lines
    }

    /// A title that says nothing but a date ("Sun 6 Sep", "2026-09-06", "6 September 2026", "Talk 6/9"
    /// is not one: "talk" is a word). Every word must be a number, a weekday or a month.
    static func isOnlyADate(_ title: String) -> Bool {
        let words = title.lowercased().split { !$0.isLetter && !$0.isNumber }
        guard !words.isEmpty, words.contains(where: { $0.first?.isNumber == true }) else { return false }
        let names = ["mon", "tue", "tues", "wed", "thu", "thur", "thurs", "fri", "sat", "sun", "monday", "tuesday", "wednesday",
                     "thursday", "friday", "saturday", "sunday", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "sept",
                     "oct", "nov", "dec", "january", "february", "march", "april", "june", "july", "august", "september", "october",
                     "november", "december", "st", "nd", "rd", "th"]
        return words.allSatisfy { word in word.allSatisfy(\.isNumber) || names.contains(String(word))
            || (word.first?.isNumber == true && ["st", "nd", "rd", "th"].contains(String(word.drop { $0.isNumber }))) }
    }

    /// "Upload checklist.txt".
    static func checklistText(_ lines: [ChecklistLine], facts: PodcastEpisodeFacts, fileName: String, madeAt: Date) -> String {
        let failed = lines.filter { $0.status == .fail }.count, missing = lines.filter { $0.status == .missing }.count
        let passed = lines.count - failed - missing
        var t = "Upload checklist: \(facts.label), \(fileName)\n\n"
        t += "Made and checked by Prakriti on \(Format.dayAndTime(madeAt)) against \(sources). "
        t += "Every number below was measured on the file in this folder. Nothing has been uploaded.\n\n"
        t += failed + missing == 0 ? "Ready to upload: every line passes.\n\n"
            : "Not ready to upload yet: \(failed) FAIL, \(missing) MISSING, \(passed) PASS.\n\n"
        t += lines.map(\.text).joined(separator: "\n") + "\n"
        return t
    }

    /// What the files were made with: when this changes, the files are out of date.
    static func fingerprint(settings: PodcastReadySettings, facts: PodcastEpisodeFacts, written: WrittenPackage?) -> String {
        var parts = [settings.showName, settings.hostName, settings.artworkPath ?? "", settings.explicit ? "x" : "",
                     settings.aiVoice ? "ai" : "", settings.numbering.rawValue, settings.callToAction, facts.title, facts.notes, facts.episodeNumber.map(String.init) ?? "",
                     facts.seasonNumber.map(String.init) ?? "", facts.kind.rawValue, written.map { "\($0.writtenAt.timeIntervalSince1970)" } ?? ""]
        if let path = settings.artworkPath, let attributes = try? FileManager.default.attributesOfItem(atPath: path) {
            parts.append("\((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)")
        }
        return parts.joined(separator: "|")
    }
}
