import Foundation
import XCTest
@testable import Prakriti

/// v2 part M13 (docs/v2/PLAN.md M13, risk R16 "copy drifts from the build"): every bold or quoted name in the Help articles, as
/// this build shows them (every capability on, since every part is built), is found in the app's own strings. A name Help uses
/// that the app does not say is a button, a menu, a status or a message that is not there, the drift Ivan's rule forbids (Help
/// describes only what the app does today).
///
/// How a name is found: in the Swift sources' string literals (comments left out), with every "\(...)" in a literal standing for
/// any short text, case and "…" ignored, and a trailing colon or comma ignored. A quoted example of several sentences
/// ("Gabriel. Up to 3 people at once. 1 other voice.") is found when each sentence is, a single capitalised word counting as a
/// person's name. A quoted heading of an article ("Find the log") is a cross-reference and is found in the articles.
///
/// Not checked, by rule: bold that ends a sentence (". , !": a lead-in, not a name) and quoted words in lower case (what someone
/// says aloud, such as "take two"). Everything else that is not a name in Prakriti is listed in `notInPrakriti` with the reason;
/// a new bold or quoted word that is neither found nor listed fails the test, and the fix is to correct the article or the app,
/// or, only when it truly is not one of Prakriti's names, to add it there with its reason.
final class HelpNamesTests: XCTestCase {
    static let notInPrakriti: [String: String] = [
        // OBS's own labels and messages (Help 03 and 10 say where to find them in OBS).
        "Audio Encoder:": "OBS", "Base (Canvas) Resolution:": "OBS", "Keyframe Interval:": "OBS", "Output (Scaled) Resolution:": "OBS",
        "Rate Control:": "OBS", "Recording Path:": "OBS", "Use B-Frames:": "OBS", "Zoom (macOS Audio Capture):": "OBS",
        "Encoding overloaded!": "OBS", "Add Chapter Marker (Hybrid MP4/MOV only)": "OBS", "320": "OBS, the audio bitrate typed in",
        "$HOME/Movies/test.mp4": "OBS, a path typed in", "a higher number means better quality": "OBS's own tooltip",
        // Lead-ins of a list: each names a kind of thing the item describes, not a control.
        "A camera through a capture card:": "lead-in", "An iPhone or a webcam:": "lead-in", "First teacher's microphone:": "lead-in, an OBS source",
        "Second teacher's microphone:": "lead-in, an OBS source", "Room microphone (optional):": "lead-in, an OBS source",
        "Zoom or other computer sound:": "lead-in, an OBS source", "A shotgun microphone": "lead-in", "Look into the lens": "lead-in",
        "Stay near the middle": "lead-in", "On the recording:": "lead-in", "The Activity window:": "lead-in", "Video and audio files:": "lead-in",
        "For files you add by hand:": "lead-in", "Made files:": "lead-in", "Each voice is linked to a face": "lead-in",
        "With each microphone on its own track": "lead-in", "Everyone else": "lead-in", "Everyone else:": "lead-in",
        "People you have named": "lead-in", "No match:": "lead-in", "Checked every time:": "lead-in", "Where it goes:": "lead-in",
        "64 GB or more:": "lead-in", "Less than 64 GB:": "lead-in", "Make Video is dimmed:": "lead-in naming Make Video, which is found",
        "Plan the Edit is dimmed:": "lead-in naming Plan the Edit, which is found",
        "A, Saffron:": "lead-in: the letter and the composition's title, found as Saffron",
        "B, Night and gold:": "lead-in: the letter and the composition's title, found as Night and gold",
        "C, The room:": "lead-in: the letter and the composition's title, found as The room",
        // Help 10 describes a message by what it says, in a lead-in, so Ivan recognises it; the message itself is the app's.
        "It says a face Prakriti cannot account for at a time:": "lead-in describing a message",
        "It says someone it heard sounds like a person you left out:": "lead-in describing a message",
        "It says the edit plan could not be made:": "lead-in describing a message",
        "It says where the video hides faces is not in the recording's folder:": "lead-in describing a message",
        "It says who appears and speaks in it has not been checked:": "lead-in describing a message",
        "It says your newest changes are not in the video yet:": "lead-in describing a message",
        "It says your newest trim, cuts or choices are not in the plan yet:": "lead-in describing a message",
        // Words Ivan types into the direction field, given as examples.
        "Calmer. Let it breathe.": "typed by Ivan", "More energetic. Faster, more frequent cuts.": "typed by Ivan",
        "Focus on the parts that are motivating or enlightening. Under 10 minutes.": "typed by Ivan",
        "Take out the story about the car.": "typed by Ivan",
        "Keep the breathing practice whole, with no zooms.": "typed by Ivan",
        "Faces of people with a release that covers their face:": "lead-in", "A line of the Ready checklist says FAIL:": "lead-in",
        "Version 2, made Thu 15 Oct 2026 at 9:41 pm. Clear, the house style.": "an example of the version line, VersionActions' \"Version \\(n), made \\(day and time). \\(sentence)\", as the M11b acceptance wrote it",
        // Examples made of a fixed name and made-up data.
        "Waiting for Your Yes: Sun 13 Sep": "a notice title with its date; the title is checked as Waiting for Your Yes, the date by NotificationTests",
    ]

    struct Found: Equatable { let article: String; let name: String }

    static var sources: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Prakriti") }

    /// Every string literal in the app's Swift sources, comment lines left out, lower case, "…" as "...".
    static func literals() throws -> (plain: String, templates: [(regex: NSRegularExpression, fixed: Int)]) {
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        var plain: [String] = []
        var templates: [(regex: NSRegularExpression, fixed: Int)] = []
        let literal = try NSRegularExpression(pattern: #""((?:[^"\\\n]|\\.)*)""#)
        // "\(...)" in a literal, and a String(format:) specifier such as %@, %d or %.2f, each stand for any short text.
        let interpolation = try NSRegularExpression(pattern: #"\\\((?:[^()]|\([^()]*\))*\)|%(?:\.\d+)?(?:@|d|f|ld|lld|s)"#)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for match in literal.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let value = normal(String(text[range]))
                plain.append(value)
                let ns = value as NSString
                let pieces = interpolation.matches(in: value, range: NSRange(location: 0, length: ns.length))
                guard !pieces.isEmpty else { continue }
                var parts: [String] = []
                var at = 0
                for piece in pieces {
                    parts.append(ns.substring(with: NSRange(location: at, length: piece.range.location - at)))
                    at = piece.range.location + piece.range.length
                }
                parts.append(ns.substring(from: at))
                let fixed = parts.joined().trimmingCharacters(in: .whitespaces).count
                guard fixed >= 3 else { continue }
                let pattern = "^" + parts.map(NSRegularExpression.escapedPattern(for:)).joined(separator: ".{1,60}?") + "$"
                if let regex = try? NSRegularExpression(pattern: pattern) { templates.append((regex, fixed)) }
            }
        }
        return (plain.joined(separator: "\n"), templates)
    }

    static func normal(_ s: String) -> String { s.replacingOccurrences(of: "\u{2026}", with: "...").lowercased() }

    /// Bold and quoted names in the visible text of every article, as this build shows it.
    static func names() throws -> [Found] {
        let folder = sources.appending(path: "Resources/Help")
        let library = HelpLibrary.load(from: folder, capabilities: Capabilities.built)
        XCTAssertEqual(library.problems, [])
        let bold = try NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
        let quoted = try NSRegularExpression(pattern: #""([^"\n]{2,200})""#)
        var out: [Found] = []
        for article in library.visible {
            let body = library.resolvedBody(article)
            let range = NSRange(body.startIndex..., in: body)
            for match in bold.matches(in: body, range: range) {
                guard let r = Range(match.range(at: 1), in: body) else { continue }
                let name = String(body[r]).trimmingCharacters(in: .whitespaces)
                if name.hasSuffix(".") || name.hasSuffix(",") || name.hasSuffix("!") { continue }
                out.append(Found(article: article.fileName, name: name))
            }
            for match in quoted.matches(in: body, range: range) {
                guard let r = Range(match.range(at: 1), in: body) else { continue }
                let name = String(body[r])
                if name == name.lowercased() { continue }
                out.append(Found(article: article.fileName, name: name))
            }
        }
        return out
    }

    /// Every heading in the articles, numbers like "4. " left out: a quoted heading is a cross-reference.
    static func headings() throws -> Set<String> {
        let folder = sources.appending(path: "Resources/Help")
        var out: Set<String> = []
        for file in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) where file.pathExtension == "md" {
            for line in try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n") where line.hasPrefix("#") {
                var heading = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if let dot = heading.firstIndex(of: "."), Int(heading[..<dot]) != nil { heading = heading[heading.index(after: dot)...].trimmingCharacters(in: .whitespaces) }
                out.insert(heading)
            }
        }
        return out
    }

    static func isFound(_ name: String, plain: String, templates: [(regex: NSRegularExpression, fixed: Int)]) -> Bool {
        func one(_ s: String) -> Bool {
            let n = normal(s).trimmingCharacters(in: .whitespaces)
            var tries = [n]
            if let last = n.last, ":,".contains(last) { tries.append(String(n.dropLast()).trimmingCharacters(in: .whitespaces)) }
            if n.hasSuffix(".") { tries.append(String(n.dropLast())) }
            for t in tries where !t.isEmpty {
                if plain.contains(t) { return true }
                let ns = t as NSString
                // A template must say most of the name in its own fixed words (at most 24 letters left to its "\(...)"), so
                // "Show \(a) \(b)" never stands for any long name that starts with Show.
                if templates.contains(where: { t.count - $0.fixed <= 24 && $0.regex.firstMatch(in: t, range: NSRange(location: 0, length: ns.length)) != nil }) { return true }
            }
            return false
        }
        if one(name) { return true }
        // An example of several sentences: each sentence, or a person's name on its own.
        let sentences = name.components(separatedBy: ". ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard sentences.count > 1 else { return false }
        return sentences.allSatisfy { s in
            let bare = s.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return (!bare.contains(" ") && bare.first?.isUppercase == true) || one(s)
        }
    }

    func testEveryNameInHelpIsOneThePrakritiAppSays() throws {
        let (plain, templates) = try Self.literals()
        let headings = try Self.headings()
        let found = try Self.names()
        XCTAssertGreaterThan(found.count, 200, "the articles' bold and quoted names were read (\(found.count))")
        var missing: [String] = []
        var checked = 0
        for item in found {
            if Self.notInPrakriti[item.name] != nil || headings.contains(item.name) { continue }
            checked += 1
            if !Self.isFound(item.name, plain: plain, templates: templates) { missing.append("\(item.article): \(item.name)") }
        }
        print("Help names: \(found.count) bold or quoted, \(checked) checked against the app's strings, \(missing.count) not found.")
        XCTAssertEqual(missing, [], "Help names something the app does not say. Fix the article or the app.")
        // The list of exceptions is only for names that still appear: one that no article uses any more is taken out.
        let used = Set(found.map(\.name))
        XCTAssertEqual(Self.notInPrakriti.keys.filter { !used.contains($0) }.sorted(), [], "listed as not Prakriti's, but no article says it now")
    }

    /// The check catches drift: a planted name that Prakriti does not say fails, a real one passes.
    func testTheCheckFindsANameThatIsNotThere() throws {
        let (plain, templates) = try Self.literals()
        XCTAssertTrue(Self.isFound("Make Again", plain: plain, templates: templates))
        XCTAssertTrue(Self.isFound("Not Gabriel", plain: plain, templates: templates), "a name built from \"Not \\(name)\"")
        XCTAssertTrue(Self.isFound("Waiting for your yes:", plain: plain, templates: templates))
        XCTAssertFalse(Self.isFound("Blur Face", plain: plain, templates: templates), "v2's draft name, never built (Hide Face is)")
        XCTAssertFalse(Self.isFound("Show Recordings With Other People", plain: plain, templates: templates), "the draft menu name; the filter is Other People Appear")
        XCTAssertFalse(Self.isFound("Publish to YouTube", plain: plain, templates: templates))
    }
}
