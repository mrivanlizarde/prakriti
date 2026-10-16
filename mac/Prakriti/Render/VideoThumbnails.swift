@preconcurrency import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// The YouTube thumbnails (v2 part M11b, docs/v2/PLAN.md M11 and section 11, Ivan Mon 12 Oct): three designed options for each
// video, never a plain screenshot, each a different composition with a one-line reason, in the recording's `Thumbnails` folder
// (`Thumbnail A.jpg` to `C.jpg`, 1280 by 720 and under 2 MB, as YouTube asks; and a full-size master of each, 1920 by 1080 from a
// 1080p recording, 3840 by 2160 only from a 4K one). The file is named VideoThumbnails.swift because People/Thumbnails.swift (the
// card picture) already holds that name in this module.
//
// How each is made:
// 1. **The frame.** Moments where the teacher's face is seen, inside what the edit plan keeps, spread through the talk, with the
//    beats' key lines first. Each frame is scored by Vision: the face's capture quality (sharp, lit, facing the camera), the
//    image's aesthetics score, and eyes open (the face's landmarks). Media Intelligence's KeyFrameAnalysisRequest was measured on
//    the first day (BUILD-LOG, v2 part M11b) and is not used: on the 13 Sep excerpt it chose 0:00, a frame any card picture leaves
//    out, and on the whole talk it took 105 s to give one moment with no score to compare. PLAN's fallback is what runs.
// 2. **The person, cut out.** Vision's person instance mask (else the foreground instance mask) at the teacher's face, so only
//    the teacher is placed on the designed ground; nobody else from the frame comes with them.
// 3. **The words.** A headline of 2 to 4 words (never the title), from the writing model (`ThumbnailWords`, Claude Sonnet by
//    default), in Alegreya Sans ExtraBold, large enough to read at 168 pixels wide, with the measured contrast against what is
//    behind it at 4.5 to 1 or more.
// 4. **Yoga Marga's own colours** (docs/v2/brand-yoga-marga.md): saffron #DC6B09, earth #975131, gold #F3CF8A, near-black #111827
//    and white. Never MKBHD's brand: one subject, few words, strong separation is the grammar, not his look.
//
// **The safe-frame rule, checked on the finished picture** (PLAN M11, Ivan: "Faces of anyone not Included are never in a
// thumbnail"): faces of anyone set to Hide Face or Leave Out for any output are hidden by `FaceHide` before anything is cut
// out or drawn, and Vision then looks for faces in each finished 1280 by 720 picture: every face it finds must sit inside the
// box of someone included, carried through the composition; anything else refuses that option. Every option passes
// `OutputGate.admitThumbnails` before the folder reaches Outputs.

enum VideoThumbnails {
    static let folderName = "Thumbnails"
    static let recordName = "thumbnails.json"
    static let stagingName = ".thumbnails"
    /// YouTube's upload size (support.google.com/youtube/answer/72431: 16:9, at least 640 wide, 2 MB on mobile).
    static let width = 1280
    static let height = 720
    static let maxBytes: Int64 = 2_000_000
    static let letters = ["A", "B", "C"]
    /// The narrowest a thumbnail is shown in YouTube's lists, the size the words must read at (Ivan, 12 Oct).
    static let smallestShown = 168.0
    /// The smallest cap height, in pixels at 168 wide, that is still read as a word: 8 px.
    static let smallestCap = 8.0
    /// The least contrast between the words and what is behind them (WCAG's 4.5 to 1 for body text).
    static let leastContrast = 4.5
    /// How many moments are looked at, and how far apart the three chosen frames must be.
    static let tries = 24
    static let apart = 20.0

    static func fileName(_ letter: String) -> String { "Thumbnail \(letter).jpg" }
    static func masterName(_ letter: String) -> String { "Thumbnail \(letter) full size.jpg" }

    // MARK: The brand

    struct Colour: Codable, Equatable, Sendable {
        var r: Double, g: Double, b: Double
        init(_ hex: UInt32) {
            r = Double((hex >> 16) & 0xFF) / 255
            g = Double((hex >> 8) & 0xFF) / 255
            b = Double(hex & 0xFF) / 255
        }
        var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
        var ci: CIColor { CIColor(red: r, green: g, blue: b) }
        /// WCAG relative luminance.
        var luminance: Double { VideoThumbnails.luminance(r: r, g: g, b: b) }
    }

    static let saffron = Colour(0xDC6B09)
    static let earth = Colour(0x975131)
    static let gold = Colour(0xF3CF8A)
    static let night = Colour(0x111827)
    static let white = Colour(0xFFFFFF)

    static func luminance(r: Double, g: Double, b: Double) -> Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    static func contrast(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    /// The three compositions, one per option.
    enum Composition: String, Codable, CaseIterable, Sendable {
        /// The teacher cut out on the right of a saffron ground, the words near-black on the left.
        case saffron
        /// The teacher cut out on the left of a near-black ground, the words gold on the right.
        case night
        /// The real frame, darkened on the side away from the teacher, the teacher lifted on it, the words white over a saffron bar.
        case frame

        var title: String {
            switch self {
            case .saffron: "Saffron"
            case .night: "Night and gold"
            case .frame: "The room"
            }
        }

        var ground: Colour? {
            switch self {
            case .saffron: VideoThumbnails.saffron
            case .night: VideoThumbnails.night
            case .frame: nil
            }
        }

        var ink: Colour {
            switch self {
            case .saffron: VideoThumbnails.night
            case .night: VideoThumbnails.gold
            case .frame: VideoThumbnails.white
            }
        }

        /// Where the teacher's face sits across the picture (0 left, 1 right); the words take the other side.
        var faceAt: Double {
            switch self {
            case .saffron: 0.70
            case .night: 0.30
            case .frame: -1
            }
        }

        func reason(at time: Double) -> String {
            switch self {
            case .saffron:
                "The school's saffron, the teacher cut out on the right, the words on the left: the brightest of the three in a list of videos. From \(Format.timecode(time))."
            case .night:
                "Gold words on near-black, the teacher on the left: the calmest of the three, with the most contrast. From \(Format.timecode(time))."
            case .frame:
                "The room as it was, darkened behind the words, the teacher lifted from it: the most like the video itself. From \(Format.timecode(time))."
            }
        }
    }

    // MARK: What was made

    struct Candidate: Codable, Equatable, Sendable {
        var letter: String
        var composition: Composition
        var headline: String
        var reason: String
        var time: Double
        var fileName: String
        var masterName: String
        var width = 0
        var height = 0
        var bytes: Int64 = 0
        var masterWidth = 0
        var masterHeight = 0
        /// Faces Vision found in the finished picture, and how many are someone included.
        var faces = 0
        var includedFaces = 0
        /// The frame's scores (0 to 1): face capture quality, aesthetics, eyes open.
        var quality = 0.0
        var aesthetics = 0.0
        var eyesOpen = false
        /// The words' cap height in pixels when the picture is shown 168 wide, and their contrast with what is behind them.
        var capAtSmallest = 0.0
        var contrast = 0.0
        /// The person was cut out by Vision's mask (false: the room composition, or no mask was found).
        var cutOut = false
        var lines: [ChecklistLine] = []

        var failed: Int { lines.filter { $0.status == .fail }.count }
    }

    struct Record: Codable, Equatable, Sendable {
        var version = 1
        var madeAt: Date
        /// The plan they were chosen from (`EditPlan.madeAt`).
        var planMadeAt: Date
        /// Who was hidden when they were made (`VideoThumbnails.signature`): a later change of choice makes them behind, and the
        /// card stops showing them until they are made again.
        var signature: String
        var source: String
        var headlinesBy: String
        var looked = 0
        var refused = 0
        var candidates: [Candidate]
        var notes: [String] = []

        var summary: String {
            guard !candidates.isEmpty else { return "No thumbnails." }
            let fails = candidates.reduce(0) { $0 + $1.failed }
            return "\(Format.count(candidates.count, "thumbnail")), 1280 by 720, " + candidates.map { "\($0.letter) \u{201C}\($0.headline)\u{201D}" }.joined(separator: ", ")
                + (fails == 0 ? "." : ". \(Format.count(fails, "check")) failed.")
        }

        func candidate(_ letter: String) -> Candidate? { candidates.first { $0.letter == letter } }

        func encoded() throws -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(self)
        }

        static func read(_ folder: URL) -> Record? {
            guard let data = try? Data(contentsOf: folder.appending(path: recordName)) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(Record.self, from: data)
        }
    }

    /// Who is hidden in pictures, as one string: the People tab rows whose faces are hidden (any output). The same rows always give
    /// the same string, so a thumbnail made under other choices is known.
    static func signature(hiddenRows: [Int]) -> String {
        "hidden:" + Set(hiddenRows).sorted().map(String.init).joined(separator: ",")
    }

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    // MARK: Choosing the frames

    /// A moment looked at, and what Vision measured on it.
    struct Look: Equatable, Sendable {
        var time: Double
        var score: Double
        var quality: Double
        var aesthetics: Double
        var eyesOpen: Bool
        /// The teacher's face in the frame (top-left, 0 to 1).
        var subject: FaceBox
        var included: [FaceBox]
        var hidden: [FaceBox]
    }

    /// The moments to look at, pure: where the subject's face is seen, every face there someone included or a hidden track,
    /// inside a kept span of the plan (never the opening line twice), 2 s from the ends; the beats' key lines first; spread.
    static func moments(_ file: PeopleFile, plan: EditPlan, subjectRow: Int, hidePlan: HidePlan, keyLines: [TimeRange], tries: Int = tries) -> [Double] {
        let kept = plan.mainSpans.map { TimeRange(start: $0.in + 0.5, end: $0.out - 0.5) }.filter { $0.end > $0.start }
        let hiddenTracks = Set(hidePlan.tracks.map(\.id))
        let all = CardPicture.moments(file).filter { moment in
            moment.time >= 2 && moment.time <= file.duration - 2
                && kept.contains { $0.start <= moment.time && moment.time <= $0.end }
                && !file.cuts.contains { abs($0 - moment.time) < CardPicture.nearCut }
                && moment.faces.contains { $0.row == subjectRow && !hiddenTracks.contains($0.track) }
        }
        func spread(_ pool: [CardPicture.Moment], _ n: Int) -> [Double] {
            guard pool.count > n else { return pool.map(\.time) }
            return (0..<n).map { i in pool[Int((Double(i) + 0.5) * Double(pool.count) / Double(n))].time }
        }
        let onKey = all.filter { m in keyLines.contains { $0.start <= m.time && m.time <= $0.end } }
        let first = spread(onKey, tries / 2)
        let rest = spread(all.filter { !first.contains($0.time) }, tries - first.count)
        return first + rest
    }

    /// The three frames: the best scores at least `apart` seconds from each other; fewer when fewer were found, then the best
    /// used again (each option is still its own composition).
    static func choose(_ looks: [Look], count: Int = 3, apart: Double = apart) -> [Look] {
        var chosen: [Look] = []
        for look in looks.sorted(by: { $0.score > $1.score }) where chosen.allSatisfy({ abs($0.time - look.time) >= apart }) {
            chosen.append(look)
            if chosen.count == count { break }
        }
        guard let best = chosen.first else { return [] }
        while chosen.count < count { chosen.append(best) }
        return chosen
    }

    /// One score for a frame: the face's capture quality counts most, then the picture's aesthetics, then open eyes, then a key line.
    static func score(quality: Double, aesthetics: Double, eyesOpen: Bool, onKeyLine: Bool) -> Double {
        quality + 0.5 * (aesthetics + 1) / 2 + (eyesOpen ? 0.3 : 0) + (onKeyLine ? 0.15 : 0)
    }

    /// Eyes open from a face's landmarks: each eye's height over its width, open at 0.18 or more (measured on test patterns of
    /// drawn eyes; a closed eye's outline reads under 0.1).
    static func eyeOpenness(_ points: [CGPoint]) -> Double {
        guard points.count >= 4 else { return 0 }
        let xs = points.map(\.x), ys = points.map(\.y)
        let w = (xs.max() ?? 0) - (xs.min() ?? 0), h = (ys.max() ?? 0) - (ys.min() ?? 0)
        return w > 0 ? Double(h / w) : 0
    }

    // MARK: Laying out

    /// How the source frame sits on the canvas: a scale and an offset, in canvas pixels, for a frame `source` pixels big.
    struct Placement: Equatable, Sendable {
        var scale: Double
        var x: Double
        var y: Double

        /// A top-left normalised box of the source frame, as a top-left normalised box of the canvas.
        func map(_ box: FaceBox, source: CGSize, canvas: CGSize) -> FaceBox {
            FaceBox(x: (box.x * source.width * scale + x) / canvas.width, y: (box.y * source.height * scale + y) / canvas.height,
                    width: box.width * source.width * scale / canvas.width, height: box.height * source.height * scale / canvas.height)
        }
    }

    /// Where the frame goes for a composition, pure. A cut-out teacher is scaled so their face is about 30% of the picture's height
    /// (never more than 1.5 times, so a 1080p frame stays sharp), their face at the composition's side, the bottom of the frame on
    /// the canvas's bottom edge or below. The room fills the canvas as it was.
    /// `attempt` (0 to 3) moves the teacher further toward the edge and, cut out, a little smaller, when the words do not fit beside
    /// them at the first place.
    static func placement(_ composition: Composition, subject: FaceBox, source: CGSize, canvas: CGSize, attempt: Int = 0) -> Placement {
        let step = Double(max(0, min(3, attempt)))
        let fill = max(canvas.width / source.width, canvas.height / source.height)
        guard composition.faceAt >= 0 else {
            // The room, a little closer (1.2 times), moved so the teacher sits on the third away from the words, the canvas always
            // covered.
            let scale = fill * (1.2 + 0.08 * step)
            let target = subject.centerX >= 0.5 ? 0.66 + 0.04 * step : 0.34 - 0.04 * step
            var x = target * canvas.width - subject.centerX * source.width * scale
            x = min(0, max(canvas.width - source.width * scale, x))
            var y = 0.2 * canvas.height - subject.y * source.height * scale
            y = min(0, max(canvas.height - source.height * scale, y))
            return Placement(scale: scale, x: x, y: y)
        }
        let wanted = 0.30 * canvas.height / max(1, subject.height * source.height)
        let scale = min(max(wanted, fill * 0.8), fill * 1.5) * (1 - 0.12 * step)
        let faceX = subject.centerX * source.width * scale
        let faceAt = composition.faceAt + (composition.faceAt >= 0.5 ? 0.05 : -0.05) * step
        var x = faceAt * canvas.width - faceX
        // The face's middle stays on the canvas at the composition's side; the frame's bottom never rises above the canvas's.
        let faceTop = subject.y * source.height * scale
        var y = 0.16 * canvas.height - faceTop
        y = max(y, canvas.height - source.height * scale)
        y = min(y, canvas.height * 0.25)
        x = min(max(x, canvas.width - source.width * scale - canvas.width), canvas.width)
        return Placement(scale: scale, x: x, y: y)
    }

    /// The box the words go in, on the side away from the teacher, in canvas pixels from the top left. `body` is how far across
    /// the teacher's outline reaches (canvas pixels, `bodySpan`): the box stops 4% of the width short of it, so the words never cross
    /// the teacher.
    static func wordsBox(_ composition: Composition, subjectOnCanvas: FaceBox, canvas: CGSize, body: ClosedRange<Double>? = nil) -> CGRect {
        let margin = canvas.width * 0.06, gap = canvas.width * 0.04
        let leftSide: Bool = switch composition {
        case .saffron: true
        case .night: false
        case .frame: subjectOnCanvas.centerX >= 0.5
        }
        var left = leftSide ? margin : canvas.width * 0.48
        var right = leftSide ? canvas.width * 0.52 : canvas.width - margin
        if let body {
            if leftSide { right = min(right, body.lowerBound - gap) } else { left = max(left, body.upperBound + gap) }
        }
        return CGRect(x: left, y: canvas.height * 0.14, width: max(0, right - left), height: canvas.height * 0.72)
    }

    /// How far across the canvas the teacher's outline reaches in the rows the words may take (14% to 86% of the height), from the
    /// cut-out's own transparency, or nil when it covers nothing there.
    static func bodySpan(_ person: CIImage, canvas: CGSize, context: CIContext) -> ClosedRange<Double>? {
        let w = 384, h = 216
        let scale = CGAffineTransform(scaleX: CGFloat(w) / canvas.width, y: CGFloat(h) / canvas.height)
        let small = person.transformed(by: scale).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        var alpha = [UInt8](repeating: 0, count: w * h)
        context.render(small, toBitmap: &alpha, rowBytes: w, bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .A8, colorSpace: nil)
        var low = Int.max, high = Int.min
        // Core Image's rows run from the bottom; the band is the same 14% to 86% either way.
        for row in Int(Double(h) * 0.14)..<Int(Double(h) * 0.86) {
            for col in 0..<w where alpha[row * w + col] > 128 {
                low = min(low, col)
                high = max(high, col)
            }
        }
        guard low <= high else { return nil }
        let k = canvas.width / Double(w)
        return Double(low) * k...Double(high + 1) * k
    }

    /// The words laid out in the box: upper case, up to four lines (one a word), the largest size that fits (never under 13.5% of the height,
    /// so their capitals are 8 pixels or more at 168 wide). Returns the lines with their size, or nil when they do not fit.
    struct Words: Equatable, Sendable {
        var lines: [String]
        var size: Double
        var capHeight: Double
        var widths: [Double]
        var lineHeight: Double
        var box: CGRect
    }

    static let face = "AlegreyaSans-ExtraBold"

    static func layOut(_ headline: String, in box: CGRect, canvas: CGSize) -> Words? {
        let text = TypeFace.prepared(headline.uppercased(), font: face)
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        // Every way to break the words into lines, one to four lines (a headline is at most four words).
        var splits: [[String]] = []
        for mask in 0..<(1 << max(0, words.count - 1)) {
            var lines: [String] = [], current: [String] = []
            for (i, word) in words.enumerated() {
                current.append(word)
                if i < words.count - 1, mask & (1 << i) != 0 { lines.append(current.joined(separator: " ")); current = [] }
            }
            lines.append(current.joined(separator: " "))
            splits.append(lines)
        }
        let smallest = canvas.height * 0.135, largest = canvas.height * 0.22
        var best: Words?
        for lines in splits {
            var size = largest
            while size >= smallest {
                guard let font = TypeFace.font(face, size: size) else { return nil }
                let widths = lines.map { width(of: $0, font: font) }
                let lineHeight = size * 1.02
                if (widths.max() ?? 0) <= box.width && lineHeight * Double(lines.count) <= box.height {
                    let candidate = Words(lines: lines, size: size, capHeight: Double(CTFontGetCapHeight(font)), widths: widths, lineHeight: lineHeight, box: box)
                    // The largest size wins; between equal sizes, fewer lines.
                    if best == nil || size > best!.size + 0.5 || (abs(size - best!.size) <= 0.5 && lines.count < best!.lines.count) { best = candidate }
                    break
                }
                size -= 4
            }
        }
        return best
    }

    static func width(of text: String, font: CTFont) -> Double {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.init(kCTFontAttributeName as String): font]))
        return Double(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// The cap height the words have when the picture is shown `smallestShown` pixels wide.
    static func capAtSmallest(_ words: Words, canvas: CGSize) -> Double {
        words.capHeight * smallestShown / canvas.width
    }

    // MARK: Making

    struct Setup: Sendable {
        var original: URL
        var plan: EditPlan
        var peopleFile: PeopleFile
        /// Everyone hidden in pictures (Hide Face or Leave Out for any output).
        var hidePlan: HidePlan
        /// The People tab rows hidden, for the signature.
        var hiddenRows: [Int]
        /// The teacher's face row (else the included row seen most).
        var subjectRow: Int
        var keyLines: [TimeRange] = []
        /// Three headlines of 2 to 4 words, and who wrote them.
        var headlines: [String]
        var headlinesBy: String
        /// The make's own staging folder: the thumbnails are made in `<staging>/.thumbnails` and admitted to `<staging>/Thumbnails`.
        var staging: URL
        var log: (@Sendable (String) -> Void)?
    }

    /// Chooses, designs, checks and admits the three thumbnails. Throws when none could be made.
    static func make(_ setup: Setup, now: Date, progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> Record {
        let started = ContinuousClock.now
        let asset = AVURLAsset(url: setup.original)
        guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw Failure(reason: "The recording has no picture, so no thumbnails were made.") }
        let transform = try await video.load(.preferredTransform)
        guard CardPicture.orientation(of: transform) == .up else {
            throw Failure(reason: "The recording was made on its side, and thumbnails are made only from an upright picture so far.")
        }
        let natural = try await video.load(.naturalSize)
        let source = CGSize(width: abs(natural.width), height: abs(natural.height))
        let master = source.height >= 2000 ? CGSize(width: 3840, height: 2160) : CGSize(width: 1920, height: 1080)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = false
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let context = CIContext(options: [.cacheIntermediates: false])
        let byTime = Dictionary(CardPicture.moments(setup.peopleFile).map { (Int(($0.time * 1000).rounded()), $0) }, uniquingKeysWith: { a, _ in a })
        let hiddenTracks = Set(setup.hidePlan.tracks.map(\.id))

        let times = moments(setup.peopleFile, plan: setup.plan, subjectRow: setup.subjectRow, hidePlan: setup.hidePlan, keyLines: setup.keyLines)
        guard !times.isEmpty else { throw Failure(reason: "The teacher's face is not seen in what the edit keeps, so no thumbnails were made.") }
        var looks: [Look] = []
        var refused = 0
        for (i, time) in times.enumerated() {
            try Task.checkCancellation()
            progress(0.7 * Double(i) / Double(times.count))
            guard let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image else { continue }
            let here = byTime[Int((time * 1000).rounded())]?.faces ?? []
            let regions = setup.hidePlan.active(at: time).isEmpty ? [] : try await FaceFollower.frame(file: setup.original, plan: setup.hidePlan, at: time).regions
            let picture = FaceHide.apply(CIImage(cgImage: frame), regions: regions)
            guard let rendered = context.createCGImage(picture, from: picture.extent) else { continue }
            let included = here.filter { !hiddenTracks.contains($0.track) }
            guard let subject = included.filter({ $0.row == setup.subjectRow }).max(by: { $0.box.area < $1.box.area }) else { continue }
            let faces = try await DetectFaceRectanglesRequest(.revision4).perform(on: rendered)
            let seen = faces.map { FaceGeometry.fromVision($0.boundingBox.cgRect) }
            guard CardPicture.accounted(found: seen, included: included.map(\.box), hidden: regions) else { refused += 1; continue }
            // The subject's face as Vision sees it in this frame: quality and eyes.
            guard let mine = faces.first(where: { FaceGeometry.padded(subject.box, by: FaceHide.pad).contains(x: FaceGeometry.fromVision($0.boundingBox.cgRect).centerX,
                                                                                                                 y: FaceGeometry.fromVision($0.boundingBox.cgRect).centerY) }) else { continue }
            var qualityRequest = DetectFaceCaptureQualityRequest()
            qualityRequest.inputFaceObservations = [mine]
            let quality = Double((try? await qualityRequest.perform(on: rendered))?.first?.captureQuality?.score ?? 0)
            var landmarksRequest = DetectFaceLandmarksRequest()
            landmarksRequest.inputFaceObservations = [mine]
            var open = false
            if let marked = (try? await landmarksRequest.perform(on: rendered))?.first, let landmarks = marked.landmarks {
                let size = CGSize(width: rendered.width, height: rendered.height)
                let left = eyeOpenness(landmarks.leftEye.pointsInImageCoordinates(size))
                let right = eyeOpenness(landmarks.rightEye.pointsInImageCoordinates(size))
                open = min(left, right) >= 0.18
            }
            let aesthetics = Double((try? await CalculateImageAestheticsScoresRequest().perform(on: rendered))?.overallScore ?? 0)
            let onKey = setup.keyLines.contains { $0.start <= time && time <= $0.end }
            looks.append(Look(time: time, score: score(quality: quality, aesthetics: aesthetics, eyesOpen: open, onKeyLine: onKey), quality: quality,
                              aesthetics: aesthetics, eyesOpen: open, subject: FaceGeometry.fromVision(mine.boundingBox.cgRect), included: included.map(\.box), hidden: regions))
        }
        let chosen = choose(looks)
        guard !chosen.isEmpty else {
            throw Failure(reason: "None of the \(Format.count(times.count, "frame")) looked at could be used for a thumbnail" + (refused > 0 ? " (\(refused) refused by the face check)." : "."))
        }
        setup.log?("thumbnails: \(Format.count(times.count, "frame")) looked at, \(refused) refused by the face check; chosen at "
                    + chosen.map { String(format: "%.1f s (score %.2f)", $0.time, $0.score) }.joined(separator: ", ") + ".")

        let build = setup.staging.appending(path: stagingName, directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: build)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        var candidates: [Candidate] = []
        var notes: [String] = []
        for (i, composition) in Composition.allCases.enumerated() {
            try Task.checkCancellation()
            progress(0.7 + 0.3 * Double(i) / 3)
            let look = chosen[i]
            let letter = letters[i]
            let headline = setup.headlines.indices.contains(i) ? setup.headlines[i] : (setup.headlines.first ?? "")
            guard let frame = try? await generator.image(at: CMTime(seconds: look.time, preferredTimescale: 600)).image else { continue }
            let hiddenFrame = FaceHide.apply(CIImage(cgImage: frame), regions: look.hidden)
            guard let hidden = context.createCGImage(hiddenFrame, from: hiddenFrame.extent) else { continue }
            var candidate = Candidate(letter: letter, composition: composition, headline: headline, reason: composition.reason(at: look.time), time: look.time,
                                      fileName: fileName(letter), masterName: masterName(letter), quality: look.quality, aesthetics: look.aesthetics, eyesOpen: look.eyesOpen)
            do {
                // Its own headline first; when that does not fit beside the teacher at a size that reads, the others in turn, those no
                // other option uses first, so the three say different things where they can.
                var designed: Designed?
                var lastFailure: Failure?
                let used = Set(candidates.map(\.headline))
                let others = setup.headlines.filter { $0 != headline }
                let order = [headline] + others.filter { !used.contains($0) } + others.filter { used.contains($0) }
                for words in order {
                    do {
                        designed = try await design(composition, frame: hidden, look: look, headline: words, canvas: master, context: context)
                        candidate.headline = words
                        break
                    } catch let failure as Failure {
                        lastFailure = failure
                    }
                }
                guard let designed else { throw lastFailure ?? Failure(reason: "It could not be drawn.") }
                candidate.cutOut = designed.cutOut
                candidate.capAtSmallest = designed.capAtSmallest
                candidate.contrast = designed.contrast
                let masterURL = build.appending(path: candidate.masterName), smallURL = build.appending(path: candidate.fileName)
                try writeJPEG(designed.image, to: masterURL, quality: 0.92)
                let small = try scaled(designed.image, to: CGSize(width: width, height: height))
                var q = 0.88
                repeat {
                    try writeJPEG(small, to: smallURL, quality: q)
                    q -= 0.08
                } while bytes(smallURL) >= maxBytes && q > 0.4
                // The check on the finished picture: Vision's faces against the included boxes carried through the composition.
                let measured = try await facesIn(smallURL)
                let accounted = CardPicture.accounted(found: measured, included: designed.included, hidden: designed.hidden)
                candidate.faces = measured.count
                candidate.includedFaces = accounted ? measured.count : measured.filter { f in designed.included.contains { FaceGeometry.padded($0, by: FaceHide.pad).contains(x: f.centerX, y: f.centerY) } }.count
                candidate.bytes = bytes(smallURL)
                (candidate.width, candidate.height) = pixelSize(smallURL)
                (candidate.masterWidth, candidate.masterHeight) = pixelSize(masterURL)
                candidate.lines = checklist(candidate, master: master, accounted: accounted)
                candidates.append(candidate)
            } catch let failure as Failure {
                notes.append("Thumbnail \(letter) (\(composition.title)) was not made: \(failure.reason)")
            }
        }
        let record = Record(madeAt: now, planMadeAt: setup.plan.madeAt, signature: signature(hiddenRows: setup.hiddenRows),
                            source: master.width >= 3840 ? "4K" : "1080p", headlinesBy: setup.headlinesBy, looked: times.count, refused: refused,
                            candidates: candidates, notes: notes)
        try record.encoded().write(to: build.appending(path: recordName))
        try OutputGate.admitThumbnails(staged: build, to: setup.staging.appending(path: folderName, directoryHint: .isDirectory), record: record)
        let elapsed = ContinuousClock.now - started
        setup.log?(String(format: "thumbnails: %@ in %.1f s.", record.summary, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18))
        progress(1)
        return record
    }

    /// One option's checklist, every line measured on the files.
    static func checklist(_ c: Candidate, master: CGSize, accounted: Bool) -> [ChecklistLine] {
        var out: [ChecklistLine] = []
        func add(_ pass: Bool, _ item: String, _ detail: String) {
            out.append(ChecklistLine(status: pass ? .pass : .fail, item: item, detail: detail, todo: pass ? nil : "Make the thumbnails again. If it fails again, the log in Activity says why."))
        }
        add(c.width == width && c.height == height, "Size", "\(c.width) by \(c.height) (1280 by 720, as YouTube asks).")
        add(c.bytes > 0 && c.bytes < maxBytes, "File size", String(format: "%.2f MB (under 2 MB, YouTube's limit on a phone).", Double(c.bytes) / 1_000_000))
        add(c.masterWidth == Int(master.width) && c.masterHeight == Int(master.height), "Full size",
            "\(c.masterWidth) by \(c.masterHeight)" + (master.width >= 3840 ? " (from a 4K recording)." : " (from a 1080p recording; 3840 by 2160 needs a 4K one)."))
        add(accounted, "People", accounted ? (c.faces == 0 ? "No face found in it." : "\(Format.count(c.faces, "face")) found, each someone you included.")
            : "A face in it is not someone you included, so it must not be used.")
        add(c.capAtSmallest >= smallestCap, "Words at 168 pixels wide", String(format: "Capital letters %.1f px tall when shown 168 wide (8 or more).", c.capAtSmallest))
        add(c.contrast >= leastContrast, "Contrast", String(format: "%.1f to 1 between the words and what is behind them (4.5 or more).", c.contrast))
        return out
    }

    struct Designed {
        var image: CGImage
        var included: [FaceBox]
        var hidden: [FaceBox]
        var cutOut: Bool
        var capAtSmallest: Double
        var contrast: Double
    }

    /// Draws one composition at the master size.
    /// `person` replaces Vision's cut-out (tests only: a drawn test-pattern figure, so a composition can be looked at without a frame
    /// of anyone, PLAN section 11, D1).
    static func design(_ composition: Composition, frame: CGImage, look: Look, headline: String, canvas: CGSize, context: CIContext,
                       person override: CIImage? = nil) async throws -> Designed {
        let source = CGSize(width: frame.width, height: frame.height)
        let frameImage = CIImage(cgImage: frame)
        let person: CIImage?
        if let override { person = override } else { person = try await cutOut(frame, at: look.subject) }
        // The first place where the words fit beside the teacher at a size that reads, else the last tried.
        var place = placement(composition, subject: look.subject, source: source, canvas: canvas)
        var move = CGAffineTransform.identity, box = CGRect.zero, subjectOnCanvas = look.subject
        for attempt in 0...3 {
            place = placement(composition, subject: look.subject, source: source, canvas: canvas, attempt: attempt)
            move = CGAffineTransform(scaleX: place.scale, y: place.scale)
                .concatenating(CGAffineTransform(translationX: place.x, y: canvas.height - source.height * place.scale - place.y))
            subjectOnCanvas = place.map(look.subject, source: source, canvas: canvas)
            let body = person.flatMap { bodySpan($0.transformed(by: move), canvas: canvas, context: context) }
            box = wordsBox(composition, subjectOnCanvas: subjectOnCanvas, canvas: canvas, body: body)
            if box.width >= canvas.width * 0.30, layOut(headline, in: box, canvas: canvas) != nil { break }
        }
        let extent = CGRect(origin: .zero, size: canvas)
        let picture: CIImage
        var included = look.included.map { place.map($0, source: source, canvas: canvas) }
        var hidden = look.hidden.map { place.map($0, source: source, canvas: canvas) }
        var cutOut = false

        if let ground = composition.ground {
            // A flat ground with a soft light behind the teacher, never a texture.
            var base = CIImage(color: ground.ci).cropped(to: extent)
            let glow = CIFilter.radialGradient()
            glow.center = CGPoint(x: subjectOnCanvas.centerX * canvas.width, y: (1 - subjectOnCanvas.centerY) * canvas.height)
            glow.radius0 = Float(canvas.height * 0.1)
            glow.radius1 = Float(canvas.height * 0.75)
            let light = composition == .saffron ? CIColor(red: 1, green: 0.62, blue: 0.24, alpha: 0.9) : CIColor(red: earth.r, green: earth.g, blue: earth.b, alpha: 0.55)
            glow.color0 = light
            glow.color1 = CIColor(red: ground.r, green: ground.g, blue: ground.b, alpha: 0)
            if let lit = glow.outputImage?.cropped(to: extent) { base = lit.composited(over: base) }
            guard let person else { throw Failure(reason: "Vision found no outline of the teacher to cut out in the frame at \(Format.timecode(look.time)).") }
            let placed = person.transformed(by: move)
            // A thin white edge around the teacher, so they stand apart from the ground at any size: their outline in white, a
            // little wider than they are.
            let edge = placed.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                                                                           "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
                                                                           "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
                .applyingFilter("CIColorClamp", parameters: [:])
                .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: canvas.height * 0.006])
            let white = CIImage(color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)).cropped(to: extent)
                .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: edge])
            picture = placed.composited(over: white.composited(over: base)).cropped(to: extent)
            cutOut = true
            // Only the teacher is drawn: no other face of the frame reaches the picture.
            included = [subjectOnCanvas]
            hidden = []
        } else {
            // The room: the frame as it was, darkened behind the words, the teacher lifted from it. The shade is as dark as it must
            // be for the words to reach 4.5 to 1 against what is really behind them, and no darker.
            guard let words = layOut(headline, in: box, canvas: canvas) else { throw Failure(reason: "The headline \u{201C}\(headline)\u{201D} does not fit at a size that reads (\(Int(box.width)) of \(Int(canvas.width)) pixels beside the teacher).") }
            let rect = textRect(words, canvas: canvas)
            let leftSide = box.minX < canvas.width / 2
            var best: (image: CGImage, contrast: Double)?
            for strength in [0.78, 0.86, 0.93, 0.97] {
                var room = frameImage.transformed(by: move).cropped(to: extent)
                let shade = CIFilter.linearGradient()
                // Full strength across the words, fading out over a fifth of the picture beyond them.
                shade.point0 = CGPoint(x: leftSide ? rect.maxX + canvas.width * 0.02 : rect.minX - canvas.width * 0.02, y: 0)
                shade.point1 = CGPoint(x: leftSide ? rect.maxX + canvas.width * 0.22 : rect.minX - canvas.width * 0.22, y: 0)
                shade.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: strength)
                shade.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
                if let dark = shade.outputImage?.cropped(to: extent) { room = dark.composited(over: room) }
                if let person {
                    let lifted = person.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.25]).transformed(by: move)
                    room = lifted.composited(over: room).cropped(to: extent)
                    cutOut = true
                }
                guard let drawn = context.createCGImage(room, from: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else { continue }
                let measured = contrast(composition.ink.luminance, meanLuminance(drawn, in: rect))
                best = (drawn, measured)
                if measured >= leastContrast { break }
            }
            guard let best else { throw Failure(reason: "The picture could not be drawn.") }
            let finished = try drawWords(words, ink: composition.ink, bar: true, on: best.image, canvas: canvas)
            return Designed(image: finished, included: included, hidden: hidden, cutOut: cutOut, capAtSmallest: capAtSmallest(words, canvas: canvas),
                            contrast: best.contrast)
        }

        guard let words = layOut(headline, in: box, canvas: canvas) else { throw Failure(reason: "The headline \u{201C}\(headline)\u{201D} does not fit at a size that reads (\(Int(box.width)) of \(Int(canvas.width)) pixels beside the teacher).") }
        guard let drawn = context.createCGImage(picture, from: extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else {
            throw Failure(reason: "The picture could not be drawn.")
        }
        // The contrast is measured on what is really behind the words, before they are drawn.
        let behind = meanLuminance(drawn, in: textRect(words, canvas: canvas))
        let finished = try drawWords(words, ink: composition.ink, bar: false, on: drawn, canvas: canvas)
        return Designed(image: finished, included: included, hidden: hidden, cutOut: cutOut, capAtSmallest: capAtSmallest(words, canvas: canvas),
                        contrast: contrast(composition.ink.luminance, behind))
    }

    /// The rectangle the words' lines take, top-left canvas pixels, vertically centred in their box.
    static func textRect(_ words: Words, canvas: CGSize) -> CGRect {
        let height = words.lineHeight * Double(words.lines.count)
        let top = words.box.midY - height / 2
        return CGRect(x: words.box.minX, y: top, width: words.widths.max() ?? 0, height: height)
    }

    /// The teacher alone, cut out of the frame: Vision's person instance at their face, else the foreground instance there; the
    /// frame's own pixels with everything else transparent, the size of the frame. Nil when neither finds them.
    static func cutOut(_ frame: CGImage, at face: FaceBox) async throws -> CIImage? {
        let handler = ImageRequestHandler(frame)
        let point = NormalizedPoint(x: face.centerX, y: 1 - face.centerY)
        if let people = try? await handler.perform(GeneratePersonInstanceMaskRequest()) {
            let instance = people.instanceAtPoint(point)
            if !instance.isEmpty, let buffer = try? people.generateMaskedImage(for: instance, imageFrom: handler) {
                return CIImage(cvPixelBuffer: buffer)
            }
        }
        if let fore = try? await handler.perform(GenerateForegroundInstanceMaskRequest()) {
            let instance = fore.instanceAtPoint(point)
            if !instance.isEmpty, let buffer = try? fore.generateMaskedImage(for: instance, imageFrom: handler) {
                return CIImage(cvPixelBuffer: buffer)
            }
        }
        return nil
    }

    /// Draws the words (and the room's saffron bar under them) with Core Text.
    static func drawWords(_ words: Words, ink: Colour, bar: Bool, on image: CGImage, canvas: CGSize) throws -> CGImage {
        let w = Int(canvas.width), h = Int(canvas.height)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let font = TypeFace.font(face, size: words.size) else { throw Failure(reason: "The typeface could not be loaded.") }
        cg.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let rect = textRect(words, canvas: canvas)
        let ascent = CTFontGetAscent(font)
        for (i, line) in words.lines.enumerated() {
            let attributed = NSAttributedString(string: line, attributes: [.init(kCTFontAttributeName as String): font,
                                                                         .init(kCTForegroundColorAttributeName as String): ink.cg])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            let top = rect.minY + words.lineHeight * Double(i)
            cg.textPosition = CGPoint(x: rect.minX, y: Double(h) - top - Double(ascent) + (words.lineHeight - words.size) / 2)
            CTLineDraw(ctLine, cg)
        }
        if bar {
            cg.setFillColor(saffron.cg)
            let barHeight = canvas.height * 0.022
            cg.fill(CGRect(x: rect.minX, y: Double(h) - rect.maxY - barHeight * 1.6, width: min(rect.width, canvas.width * 0.24), height: barHeight))
        }
        guard let out = cg.makeImage() else { throw Failure(reason: "The words could not be drawn.") }
        return out
    }

    /// The mean WCAG luminance of a top-left rectangle of an image (sampled on a grid of 40 by 20 points).
    static func meanLuminance(_ image: CGImage, in rect: CGRect) -> Double {
        let w = image.width, h = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              rect.width > 0, rect.height > 0 else { return 0 }
        cg.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = cg.data else { return 0 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var total = 0.0, n = 0
        for i in 0..<40 {
            for j in 0..<20 {
                let x = Int(rect.minX + rect.width * (Double(i) + 0.5) / 40), y = Int(rect.minY + rect.height * (Double(j) + 0.5) / 20)
                guard x >= 0, x < w, y >= 0, y < h else { continue }
                let o = (y * w + x) * 4
                total += luminance(r: Double(pixels[o]) / 255, g: Double(pixels[o + 1]) / 255, b: Double(pixels[o + 2]) / 255)
                n += 1
            }
        }
        return n == 0 ? 0 : total / Double(n)
    }

    static func scaled(_ image: CGImage, to size: CGSize) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw Failure(reason: "The picture could not be scaled.") }
        cg.interpolationQuality = .high
        cg.draw(image, in: CGRect(origin: .zero, size: size))
        guard let out = cg.makeImage() else { throw Failure(reason: "The picture could not be scaled.") }
        return out
    }

    static func writeJPEG(_ image: CGImage, to url: URL, quality: Double) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw Failure(reason: "The picture could not be written.")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure(reason: "The picture could not be written.") }
    }

    static func bytes(_ url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.int64Value ?? 0
    }

    static func pixelSize(_ url: URL) -> (Int, Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return (0, 0) }
        return ((properties[kCGImagePropertyPixelWidth] as? Int) ?? 0, (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0)
    }

    /// The faces Vision finds in a written picture, as top-left boxes.
    static func facesIn(_ url: URL) async throws -> [FaceBox] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure(reason: "The written picture does not open.")
        }
        return try await DetectFaceRectanglesRequest(.revision4).perform(on: image).map { FaceGeometry.fromVision($0.boundingBox.cgRect) }
    }
}
