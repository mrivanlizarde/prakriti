import Foundation
import XCTest
@testable import Prakriti

/// v2 part M5a, check 3 (docs/v2/PLAN.md M5, risk R18): how many of the person names in the 13 Sep talk
/// Apple's tagger finds, on the exact text a cloud request would carry (`Writer.writingRequest`), and which
/// of its finds are not names. Run only by `make accept-names`. Needs the 13 Sep transcript from `make
/// accept` in ~/Prakriti/Dev/Outputs and LM Studio's server with Qwen3.8-27B.
///
/// There is no hand-made answer key (a person would have to read the talk), so the reference is built on
/// this Mac: Qwen3.8-27B in LM Studio lists every person's name in the transcript and judges each of the
/// tagger's finds, and a name counts only if it really occurs in the text. Nothing leaves the Mac.
///
/// The report names only Gabriel and Serenity; every other name is "name 1", "name 2" with its counts,
/// so no student's name is written anywhere. Finds that are not names are written as found (they are words).
@MainActor
final class NameRecallAcceptanceTests: XCTestCase {
    static let shown: Set<String> = ["gabriel", "serenity", "galindo", "todesco"]

    func testTheTaggersRecallOnThe13SepTalk() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "names" else { throw XCTSkip("Run with make accept-names") }
        let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Prakriti/Dev/Outputs/2026-09-13 18-25-44", directoryHint: .isDirectory)
        let input = try XCTUnwrap(WritingInput.from(folder: folder, clock: nil, duration: 948, applyLexicon: true, label: "Sun 13 Sep",
                                                    fileName: "2026-09-13 18-25-44.mp4", kind: .talk, knownSerenity: false),
                                  "make accept first: no transcript in \(folder.path)")
        let lines = WritingLine.lines(input.cues)
        let rules = WritingRules.forLength(lines.last?.end ?? 0)
        let request = Writer.writingRequest(input, lines: lines, rules: rules, length: lines.last?.end ?? 0)
        let text = request.user
        var report = ["Name recall, v2 part M5a check 3, \(Date().formatted(date: .abbreviated, time: .standard))",
                      "Text: the user message a cloud writing request would carry for the 13 Sep talk (\(lines.count) lines, \(text.count) characters)", ""]
        defer {
            let out = SnapshotRenderer.milestoneFolder()
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            try? report.joined(separator: "\n").appending("\n").write(to: out.appending(path: "acceptance-names.txt"), atomically: true, encoding: .utf8)
        }

        // 1. The tagger, exactly as the lock calls it.
        let found = NameTokens.findNames(in: text)

        // 2. The reference, on this Mac.
        let client = LMStudioClient(address: AppSettings.defaultLMStudioAddress, model: AppSettings.defaultLMStudioModel)
        try await client.prepare()
        let ask = ModelRequest(
            system: "You find people's names in a transcript. You answer with JSON only.",
            user: """
                Below is a transcript of a talk. Do two things.
                1. List every name of a person that appears in it, exactly as written: first names, surnames, full names and \
                nicknames, of anyone at all (the speaker, people in the room, family, teachers, historical or public figures). \
                Do not list places, schools, practices or words that only look like names.
                2. For each word in this list, say whether the transcript uses it as a person's name: \(found.map { "\"\($0)\"" }.joined(separator: ", ")).
                Answer exactly as {"names": ["..."], "judged": {"word": true}}.

                Transcript:
                \(lines.map(\.text).joined(separator: "\n"))
                """, shape: .check)
        let started = Date()
        let reply = try await client.complete(ask)
        _ = await client.release()
        let object = try XCTUnwrap(WritingCheck.jsonObject(reply.text), "Qwen answered with JSON")
        let listed = (object["names"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let judged = object["judged"] as? [String: Bool] ?? [:]

        func occurrences(_ name: String, in text: String) -> Int {
            let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: name) + #"(?![\p{L}\p{N}])"#
            return (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
                .numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) ?? 0
        }
        // A name counts once, by its longest written form; its single words are covered by it.
        var reference: [String] = []
        for name in (listed + found.filter { judged[$0] == true }) where occurrences(name, in: text) > 0 {
            if !reference.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { reference.append(name) }
        }
        let falseFinds = found.filter { name in judged[name] == false && !reference.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }

        // 3. Recall by mentions: every occurrence of a reference name, and how many are still there after
        //    the tokens, first with the tagger alone, then as the lock ships (with its always-replaced names).
        let alone = NameTokens.tokenize([text], keep: [], always: []).texts[0]
        // "As the lock shipped" is part M5a's lock (the tagger plus "Serenity" always replaced). Part LOCK (14 Oct) retired
        // both for the lock, so this measures the tagger for the record and for the names said aloud step.
        let shipped = NameTokens.tokenize([text], keep: [], always: ["Serenity"]).texts[0]
        var total = 0, leftAlone = 0, leftShipped = 0, distinctFound = 0
        var rows: [String] = []
        var masked = 0
        for name in reference.sorted(by: { occurrences($0, in: text) > occurrences($1, in: text) }) {
            let n = occurrences(name, in: text)
            let a = occurrences(name, in: alone), s = occurrences(name, in: shipped)
            total += n; leftAlone += a; leftShipped += s
            if a < n { distinctFound += 1 }
            let label: String
            if NameTokens.words(name).allSatisfy({ Self.shown.contains($0.lowercased()) }) { label = name } else { masked += 1; label = "name \(masked)" }
            rows.append("  \(label): \(n) mention\(n == 1 ? "" : "s"); the tagger replaced \(n - a); as shipped \(n - s)")
        }
        let recallAlone = total == 0 ? 1 : Double(total - leftAlone) / Double(total)
        let recallShipped = total == 0 ? 1 : Double(total - leftShipped) / Double(total)
        report += ["Reference: Qwen3.8-27B in LM Studio, \(String(format: "%.0f", Date().timeIntervalSince(started))) s; \(reference.count) distinct names, \(total) mentions",
                   "Tagger (NLTagger .nameType, personalName, joinNames): \(found.count) finds, of which \(found.count - falseFinds.count) are names",
                   "Recall, distinct names: \(distinctFound) of \(reference.count)",
                   String(format: "Recall, mentions, the tagger alone: %d of %d (%.0f%%)", total - leftAlone, total, recallAlone * 100),
                   String(format: "Recall, mentions, as the lock ships (always replacing the teacher who has not agreed): %d of %d (%.0f%%)", total - leftShipped, total, recallShipped * 100),
                   "Plan threshold for cloud writing of real recordings (risk R18): 90%",
                   "", "Each name (only Gabriel and Serenity are named here):"] + rows
        report += ["", "Finds that are not names (\(falseFinds.count)): \(falseFinds.isEmpty ? "none" : falseFinds.joined(separator: ", "))"]
        XCTAssertGreaterThan(reference.count, 0, "the talk names someone")
    }
}
