import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The show's artwork, checked against Apple's rules before it is put in an episode.
///
/// Apple Podcasts, "Show Cover" (podcasters.apple.com/support/5514, read 10 Oct): square, 1400 by
/// 1400 to 3000 by 3000 pixels, PNG or JPG, no transparency and no alpha channel. Apple's older
/// artwork guidance also asks for the RGB color space and, for JPEG, a file under 512 KB; both are
/// checked too, because a host that re-reads the file can still refuse it. The image is read by what
/// it is (ImageIO), never by its file name's ending.
struct ArtworkCheck: Codable, Equatable, Sendable {
    var fileName: String
    var width: Int?
    var height: Int?
    /// "JPEG" or "PNG", or what it really is.
    var format: String?
    var colorModel: String?
    var hasAlpha: Bool = false
    var bytes: Int64 = 0
    /// One plain sentence per rule it breaks. Empty: it passes.
    var problems: [String] = []

    static let smallest = 1400
    static let largest = 3000
    static let largestBytes: Int64 = 512 * 1024

    var passes: Bool { problems.isEmpty }

    /// "3000 by 3000 px JPEG, RGB, 420 KB".
    var line: String {
        var parts: [String] = []
        if let width, let height { parts.append("\(width) by \(height) px \(format ?? "image")") } else if let format { parts.append(format) }
        if let colorModel { parts.append(colorModel) }
        parts.append(Format.kilobytes(bytes))
        return parts.joined(separator: ", ")
    }

    /// The MIME type it is embedded with.
    var mime: String { format == "PNG" ? "image/png" : "image/jpeg" }

    static func check(_ url: URL) -> ArtworkCheck {
        var result = ArtworkCheck(fileName: url.lastPathComponent)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            result.problems = ["The file is not there any more. Choose it again in Settings, Outputs."]
            return result
        }
        result.bytes = ((try? fm.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source) as String?,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            result.problems = ["It does not open as an image."]
            return result
        }
        let uti = UTType(type)
        result.format = uti == .jpeg ? "JPEG" : uti == .png ? "PNG" : (uti?.preferredFilenameExtension?.uppercased() ?? type)
        result.width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue
        result.height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        result.colorModel = properties[kCGImagePropertyColorModel] as? String
        result.hasAlpha = (properties[kCGImagePropertyHasAlpha] as? NSNumber)?.boolValue ?? false

        var problems: [String] = []
        if uti != .jpeg && uti != .png {
            problems.append("It is \(result.format ?? "not a JPEG or PNG"); Apple takes JPEG or PNG only.")
        }
        if let w = result.width, let h = result.height {
            if w != h { problems.append("It is \(w) by \(h) px; it must be square.") }
            if min(w, h) < smallest { problems.append("It is \(w) by \(h) px; the smallest Apple takes is \(smallest) by \(smallest).") }
            if max(w, h) > largest { problems.append("It is \(w) by \(h) px; the largest Apple takes is \(largest) by \(largest).") }
        } else {
            problems.append("Its size in pixels could not be read.")
        }
        if let model = result.colorModel, model != (kCGImagePropertyColorModelRGB as String) {
            problems.append("Its colors are \(model); Apple asks for RGB.")
        }
        if result.hasAlpha { problems.append("It has an alpha channel (transparency); Apple does not allow one.") }
        if result.bytes > largestBytes {
            problems.append("It is \(Format.kilobytes(result.bytes)); keep it under 512 KB (save the JPEG at a lower quality).")
        }
        result.problems = problems
        return result
    }
}
