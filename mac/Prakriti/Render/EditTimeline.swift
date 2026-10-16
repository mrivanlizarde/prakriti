import CoreMedia
import Foundation

// The edit plan as a timeline (v2 part M8b): each kept span as whole video frames, where it sits on the edited clock, and
// the audio samples that go with it. Every renderer reads it, the picture (`CompositionBuilder`), the sound
// (`VideoAudio`) and the captions (`Captions`), so the picture and the sound are cut on the same frame by construction
// (research-edit-engine.md 1.8, "Sync"), and the made file's length is the sum of the kept spans.
//
// Load-bearing: positions on the edited clock are counted in frames, never added up in seconds. 365 spans of 1001/30000 s
// added as doubles drift by microseconds; counted in frames they are exact, and the audio's sample boundaries are rounded
// from those exact times once, so no join is ever a sample early or late against the picture.

struct EditTimeline: Equatable, Sendable {
    struct Piece: Equatable, Sendable {
        /// The plan's span id ("k1").
        var id: String
        /// First frame kept and the frame after the last, on the original's clock, in frames.
        var sourceFrame: Int64
        var frames: Int64
        /// Where it starts on the edited clock, in frames.
        var editFrame: Int64
        /// A piece of the opening line (v2 part M9d): played first and again in its place, so a moment of the original it holds
        /// is found in the talk's own piece by `editTime`, never here.
        var hook = false
        /// A moment from another recording (v2 part M12b): the path of that recording's original, whose frames `sourceFrame` counts.
        /// Nil for the recording's own pieces. Its frames are never this recording's, so no lookup of the original's clock finds it.
        var source: String?
        /// Its join at each end in frames (0: a hard cut), and its colour match.
        var join = 0
        var colour: [Double]?

        var insert: Bool { source != nil }
    }

    var frame: FrameDuration
    var pieces: [Piece]
    /// Frames the last kept frame is held after the last piece (v2 part M9a: speech ends 5 s before the last frame, the
    /// plan's `hold`). The sound is silent there. 0 when nothing is held.
    var holdFrames: Int64 = 0

    static let sampleRate = 48_000

    /// The timeline of a plan. Each span's ends are taken to the nearest frame (the plan puts them on frames already,
    /// `PlanValidation`); a span cut short by the end of the picture (`pictureFrames`) keeps what the picture has.
    init(plan: EditPlan, pictureFrames: Int64? = nil) {
        frame = plan.frameDuration
        var pieces: [Piece] = []
        var at: Int64 = 0
        for span in plan.spans {
            let first = Int64((span.in / plan.frameDuration.seconds).rounded())
            var last = Int64((span.out / plan.frameDuration.seconds).rounded())
            // The original's picture length bounds its own pieces only: a moment's frames are another recording's (v2 part M12b).
            if let pictureFrames, !span.isInsert { last = min(last, pictureFrames) }
            guard last > first else { continue }
            pieces.append(Piece(id: span.id, sourceFrame: first, frames: last - first, editFrame: at, hook: span.isHook,
                                source: span.isInsert ? (span.sourceFile ?? span.source) : nil, join: span.isInsert ? (span.join ?? 0) : 0,
                                colour: span.isInsert ? span.colour : nil))
            at += last - first
        }
        self.pieces = pieces
        if !pieces.isEmpty, plan.holdSeconds > 0 {
            holdFrames = Int64((plan.holdSeconds / plan.frameDuration.seconds).rounded())
        }
    }

    init(frame: FrameDuration, pieces: [Piece], holdFrames: Int64 = 0) {
        self.frame = frame
        self.pieces = pieces
        self.holdFrames = holdFrames
    }

    /// Frames of the pieces alone, without the hold.
    var keptFrames: Int64 { pieces.reduce(0) { $0 + $1.frames } }
    var totalFrames: Int64 { keptFrames + holdFrames }
    var duration: Double { seconds(totalFrames) }
    /// The original's frame the hold shows: the last kept frame.
    var holdSourceFrame: Int64? { pieces.last.map { $0.sourceFrame + $0.frames - 1 } }

    func seconds(_ frames: Int64) -> Double { Double(frames * frame.value) / Double(frame.timescale) }

    /// A frame count as a CMTime, exact.
    func time(_ frames: Int64) -> CMTime { CMTime(value: frames * frame.value, timescale: CMTimeScale(frame.timescale)) }

    /// The audio sample a moment of the edited clock falls on, rounded once from the exact frame time.
    func sample(atFrame frames: Int64) -> Int64 {
        Int64((Double(frames * frame.value) * Double(Self.sampleRate) / Double(frame.timescale)).rounded())
    }

    /// The samples of the source each piece takes, and where they go in the edited sound. The lengths add up to exactly
    /// the edited length in samples, so the sound is as long as the picture.
    struct AudioPiece: Equatable, Sendable {
        var sourceSample: Int64
        var editSample: Int64
        var samples: Int64
        /// Which recording's sound it takes: nil for this recording's own, else the other original's path (v2 part M12b).
        var source: String? = nil
    }

    var audioPieces: [AudioPiece] {
        pieces.map { piece in
            let editStart = sample(atFrame: piece.editFrame), editEnd = sample(atFrame: piece.editFrame + piece.frames)
            return AudioPiece(sourceSample: sample(atFrame: piece.sourceFrame), editSample: editStart, samples: editEnd - editStart, source: piece.source)
        }
    }

    /// The same timeline with only this recording's own pieces, each where it is (v2 part M12b): for what reads the original's
    /// frames by number (the faces hidden), which must never count another recording's frames as its own.
    var ownPieces: EditTimeline {
        EditTimeline(frame: frame, pieces: pieces.filter { !$0.insert }, holdFrames: holdFrames)
    }

    var totalSamples: Int64 { sample(atFrame: totalFrames) }

    /// A moment of the original on the edited clock, or nil when the plan took it out. A moment the opening line repeats is
    /// found in its place in the talk (v2 part M9d): the opening line's pieces are skipped.
    func editTime(_ original: Double) -> Double? {
        let f = original / frame.seconds
        for piece in pieces where !piece.hook && !piece.insert && f >= Double(piece.sourceFrame) - 1e-6 && f <= Double(piece.sourceFrame + piece.frames) + 1e-6 {
            return (f - Double(piece.sourceFrame) + Double(piece.editFrame)) * frame.seconds
        }
        return nil
    }

    /// A moment of the original inside one span's piece on the edited clock (the opening line's own, or the talk's), or nil.
    func editTime(_ original: Double, span: String) -> Double? {
        let f = original / frame.seconds
        guard let piece = pieces.first(where: { $0.id == span }),
              f >= Double(piece.sourceFrame) - 1e-6 && f <= Double(piece.sourceFrame + piece.frames) + 1e-6 else { return nil }
        return (f - Double(piece.sourceFrame) + Double(piece.editFrame)) * frame.seconds
    }

    /// Frames the opening line takes at the start (v2 part M9d), 0 when the video opens on the talk.
    var hookFrames: Int64 { pieces.prefix { $0.hook }.reduce(0) { $0 + $1.frames } }

    /// A moment of the edited clock on the original's. A moment exactly at a join is the first frame of the piece after it,
    /// the frame the video shows there (v2 part M8d: the picture output check read the frame before the cut instead, a frame
    /// the video never shows, and so the wrong hidden regions); only the very end of the video maps to its last piece's end.
    func originalTime(_ edited: Double) -> Double? {
        let f = edited / frame.seconds
        for piece in pieces where f >= Double(piece.editFrame) - 1e-6 && f < Double(piece.editFrame + piece.frames) - 1e-6 {
            // A moment from another recording (v2 part M12b) has no moment of this original.
            if piece.insert { return nil }
            return (f - Double(piece.editFrame) + Double(piece.sourceFrame)) * frame.seconds
        }
        // The held last frame (v2 part M9a): every moment of the hold shows the last kept frame.
        if let last = pieces.last, holdFrames > 0, f >= Double(last.editFrame + last.frames) - 1e-6,
           f <= Double(totalFrames) + 1e-6, let shown = holdSourceFrame {
            return Double(shown) * frame.seconds
        }
        if let last = pieces.last, abs(f - Double(last.editFrame + last.frames)) <= 1e-6 {
            return Double(last.sourceFrame + last.frames) * frame.seconds
        }
        return nil
    }

    /// The first edited moment at or after an original moment that the plan took out: where a chapter that starts inside a
    /// removed stretch lands.
    func editTimeAtOrAfter(_ original: Double) -> Double? {
        if let t = editTime(original) { return t }
        let f = original / frame.seconds
        return pieces.first { !$0.hook && !$0.insert && Double($0.sourceFrame) >= f }.map { seconds($0.editFrame) }
    }
}
