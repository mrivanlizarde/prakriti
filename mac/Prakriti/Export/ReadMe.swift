import Foundation

// `Read Me.txt` beside the timelines (v2 part M10a, docs/v2/PLAN.md M10): five lines, how to open each file and what is switched
// off, in plain words. Written for someone opening the folder cold, months later.
enum TimelineReadMe {
    static let fileName = "Read Me.txt"

    /// The five lines. `captions` is the `.srt` file's name beside the timelines.
    static func lines(captions: String, privacySafe: Bool = false) -> [String] {
        [
            "Final Cut Pro: double-click \u{201C}\(FCPXMLVersion.finalCut.fileName)\u{201D}, or choose File > Import > XML in Final Cut Pro and select it.",
            "DaVinci Resolve 20: choose File > Import > Timeline, select \u{201C}\(FCPXMLVersion.resolve.fileName)\u{201D} and turn on Use sizing information, so the punch-ins come in.",
            "If the captions do not come into Resolve, choose File > Import > Subtitle, select \u{201C}\(captions)\u{201D} and drag it onto the timeline.",
            TimelineAnimations.verified
                ? "Switched off: each text has an editable copy on the lane above it, turned off."
                : "Switched off: each text has an editable copy on the lane above it, turned off, and each slow push-in is a marker named \u{201C}\(FCPXMLWriter.pushInMarker)\u{201D} instead of a move.",
            privacySafe
                ? "Keep this folder together: both timelines use the \(TimelineMedia.folderName) and \(GraphicsClips.folderName) folders inside it. The media is a privacy-safe copy: hidden faces stay hidden and removed speech stays out, even with every effect off."
                : "Keep this folder together: both timelines use the \(TimelineMedia.folderName) and \(GraphicsClips.folderName) folders inside it.",
        ]
    }

    static func text(captions: String, privacySafe: Bool = false) -> String {
        lines(captions: captions, privacySafe: privacySafe).joined(separator: "\n") + "\n"
    }
}
