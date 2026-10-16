import CoreText
import Foundation

// The typeface burned into the edited video (v2 part M9b, docs/v2/PLAN.md M9, research-edit-engine.md 2.7): **Alegreya Sans**,
// the school's own supporting face (docs/v2/brand-yoga-marga.md, read from yogamarga.school), under the SIL Open Font
// License 1.1, which allows it to be bundled and burned into pictures. Chosen Thu 15 Oct from a contact sheet of the IAST test
// string and every IAST letter in four faces (Noto Sans, Source Sans 3, Inter, Alegreya Sans), each rendered and looked at
// (`screens/mac/v2-m9b/typeface.png`). All four draw the test string; Alegreya Sans draws four rare letters from a letter and
// its combining marks (`prepared`), which it places correctly, and it is the face Yoga Marga already uses (BUILD-LOG, v2
// part M9b). Never SF Pro or New York in a video: their licence for burned pixels is not established (research 2.7).
//
// The three weights and the licence are copied from Google Fonts' repository (github.com/google/fonts, `ofl/alegreyasans`,
// Wed 14 Oct 2026) into `Resources/Fonts`, which the app carries as one folder (project.yml). They are registered for this
// process only, never installed on the Mac.

enum TypeFace {
    /// The family's PostScript names, by the weight the overlays use.
    static let regular = "AlegreyaSans-Regular"
    static let medium = "AlegreyaSans-Medium"
    static let bold = "AlegreyaSans-Bold"
    /// The thumbnails' headlines (v2 part M11b): the family's ExtraBold, from the same Google Fonts copy as the other three (its
    /// SHA-256 3861f08a77d5... matches the file read on Wed 14 Oct for the M9b contact sheet).
    static let extraBold = "AlegreyaSans-ExtraBold"
    static let familyName = "Alegreya Sans"
    static let files = ["AlegreyaSans-Regular.ttf", "AlegreyaSans-Medium.ttf", "AlegreyaSans-Bold.ttf", "AlegreyaSans-ExtraBold.ttf"]
    static let licenceFile = "OFL.txt"

    /// The IAST test string of PLAN M9 check 2 (research 2.7): every burned face must draw each of its characters.
    static let iastTest = "Prāṇāyāma, Īśvara praṇidhāna, Kṛṣṇamācārya"
    /// Every IAST letter research 2.7 lists, with vocalic long l (U+1E39), lower and upper case, for the coverage test:
    /// ā ī ū ṛ ṝ ḷ ḹ ṅ ñ ṭ ḍ ṇ ś ṣ ṃ ḥ and their capitals.
    static let iastLetters = "\u{101}\u{12B}\u{16B}\u{1E5B}\u{1E5D}\u{1E37}\u{1E39}\u{1E45}\u{F1}\u{1E6D}\u{1E0D}\u{1E47}\u{15B}\u{1E63}\u{1E43}\u{1E25}"
        + "\u{100}\u{12A}\u{16A}\u{1E5A}\u{1E5C}\u{1E36}\u{1E38}\u{1E44}\u{D1}\u{1E6C}\u{1E0C}\u{1E46}\u{15A}\u{1E62}\u{1E42}\u{1E24}"

    /// The folder of the bundled fonts inside the app.
    static var folder: URL? { Bundle.main.url(forResource: "Fonts", withExtension: nil) }

    /// Registers the bundled faces for this process, once. Returns whether all four are usable by name afterwards.
    @discardableResult
    static func register() -> Bool {
        _ = registration
        return files.indices.allSatisfy { i in isAvailable([regular, medium, bold, extraBold][i]) }
    }

    private static let registration: Void = {
        guard let folder else { return }
        for file in files {
            let url = folder.appending(path: file)
            // Already registered (a second process start in tests) is not an error worth reporting.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func isAvailable(_ name: String) -> Bool {
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        return (CTFontCopyPostScriptName(font) as String) == name
    }

    /// The face at a size, registered first. Falls back to nothing: a missing face is an error the overlay step reports.
    static func font(_ name: String, size: CGFloat) -> CTFont? {
        register()
        guard isAvailable(name) else { return nil }
        return CTFontCreateWithName(name as CFString, size, nil)
    }

    /// `text` as the face can draw it: a letter the face has no single glyph for (Alegreya Sans lacks four rare IAST letters
    /// as one glyph: ṝ, ḹ, Ṝ and Ḹ, measured Thu 15 Oct) is written as its letter and combining marks (Unicode's canonical
    /// decomposition), which the face places itself; rendered and looked at on the contact sheet. Every other letter stays
    /// as it was, so the face's own precomposed glyphs are used wherever they exist.
    static func prepared(_ text: String, font name: String) -> String {
        guard let font = font(name, size: 40) else { return text }
        var out = ""
        for character in text {
            let single = String(character)
            out += missing(in: single, font: font).isEmpty ? single : single.decomposedStringWithCanonicalMapping
        }
        return out
    }

    /// The characters of `text` the face has no glyph for (spaces and punctuation included in the test). Empty means every
    /// character is drawn by the face itself, never by a fallback.
    static func missing(in text: String, font: CTFont) -> [Character] {
        var out: [Character] = []
        for character in text where !character.isWhitespace {
            let units = Array(String(character).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: units.count)
            let ok = CTFontGetGlyphsForCharacters(font, units, &glyphs, units.count)
            if !ok || glyphs.contains(0) { out.append(character) }
        }
        return out
    }
}
