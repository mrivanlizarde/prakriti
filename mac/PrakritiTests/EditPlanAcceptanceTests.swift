import Foundation
import SwiftData
import XCTest
@testable import Prakriti

/// v2 part M8a's acceptance (docs/v2/PLAN.md M8, check 2, the half measured on the plan against the original's sound;
/// the halves that need Parakeet on a made video wait for M8b). On the REAL 13 Sep talk, in development, through the app:
/// made as usual, then Plan the Edit, then Make Again (which must plan again by itself, the same plan), then the plan read
/// back from `edit-plan.json` and measured against the original's own samples, decoded here:
///
/// - every cut point sits 20 dB or more under the speech level for the 20 ms around it;
/// - no silence in the edit is longer than the trigger (0.60 s after punctuation, 0.40 s inside a sentence) unless it
///   follows a breath or practice cue or a question, and the shortened pauses' median is within 50 ms of the target;
/// - every kept span starts and ends on a video frame, so the kept length is a whole number of frames and the picture
///   and the sound are cut on the same frame;
/// - `PlanValidation` passes on the file as written, and Plan the Edit made no file but the plan.
///
/// Measured and reported, not gated in M8a: each join made the way M8b will join it (a 20 ms equal-power crossfade) and
/// its largest sample jump against the largest in the 50 ms around each cut; how many of the transcript's "um" and "uh"
/// the plan takes out. Then the 6 Sep talk is planned from its development transcript the same way (no make).
///
///   cd ~/Code/prakriti/mac && make accept-video MILESTONE=v2-m8a
///
/// Skipped unless PRAKRITI_ACCEPTANCE=video. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the
/// originals are only read, checked by size and date before and after. Never a class, never the archive. No picture of
/// the talk is drawn (docs/v2/PLAN.md section 11, D1): every check here is a number.
@MainActor
final class EditPlanAcceptanceTests: XCTestCase {
    func testThePlanOnTheThirteenthOfSeptember() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "video" else {
            throw XCTSkip("Reads the 13 Sep and 6 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-video MILESTONE=v2-m8a")
        }
        let paths = AppPaths(mode: .development)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(Int(environment["PRAKRITI_STABLE_WAIT"] ?? "") ?? 5)
        // The parts of the talk are v2 part M9d's: this check measures what it always measured, with no model asked for them.
        model.runner.askForBeats = false
        model.log.write("Acceptance test for v2 part M8a (the edit plan) started.")

        let talk13 = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        let talk06 = paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4")
        for file in [talk13, talk06] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing: \(file.path)")
            XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { file.path.contains($0) }, "never a class")
        }
        let before = [talk13, talk06].map(fingerprint)
        var report = ["v2 part M8a acceptance (the edit plan), \(Date().formatted(date: .abbreviated, time: .standard))", ""]
        var verdicts: [(String, Bool, String)] = []
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            verdicts.append((name, pass, measured))
            XCTAssertTrue(pass, "\(name): \(measured)")
        }

        // 1. Made as usual, then Plan the Edit.
        let recording = Recording(filePath: talk13.path, recordedAt: AppModel.dateInName(talk13.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: talk13)
        recording.kind = .talk
        try model.context.save()
        await model.runner.process(recording, trigger: .byHand)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        XCTAssertFalse(recording.latestRun?.steps.contains { $0.name == PipelineStep.planEdit.title } ?? true,
                       "a make plans nothing until Ivan asks once")
        let folder = try XCTUnwrap(recording.outputFolder.map { URL(fileURLWithPath: $0, isDirectory: true) })
        precondition(folder.path.hasPrefix(paths.outputs.path + "/"))
        let filesBefore = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
        XCTAssertFalse(filesBefore.contains(EditPlan.fileName))
        XCTAssertTrue(model.canPlanEdit(recording))
        model.planEdit(recording)
        let planStarted = Date()
        while model.planning.contains(recording.id) { try await Task.sleep(for: .milliseconds(100)) }
        let planSeconds = Date().timeIntervalSince(planStarted)
        XCTAssertNil(model.planProblems[recording.id], model.planProblems[recording.id] ?? "")
        let filesAfter = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
        verdict("Plan the Edit makes only edit-plan.json", filesAfter.subtracting(filesBefore) == [EditPlan.fileName] && filesBefore.isSubset(of: filesAfter),
                "new files: \(filesAfter.subtracting(filesBefore).sorted()), gone: \(filesBefore.subtracting(filesAfter).sorted()), in \(String(format: "%.1f", planSeconds)) s")
        XCTAssertTrue(recording.madeFiles.contains(EditPlan.fileName))
        let planURL = folder.appending(path: EditPlan.fileName)
        let planData = try Data(contentsOf: planURL)
        let plan = try XCTUnwrap(EditPlan.decode(planData), "edit-plan.json reads back")
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folder.appending(path: TranscriptFiles.asHeard))))
        let problems = PlanValidation.check(plan, words: words)
        verdict("PlanValidation on the file as written (rules 1 to 6)", problems.isEmpty, problems.isEmpty ? "no problem" : problems.map(\.line).joined(separator: "; "))
        report.append("Plan: \(plan.summary)")
        report.append("Schema \(plan.schema), frame \(plan.frameDuration), floor \(plan.envelope.floorDB) dB, speech \(plan.envelope.speechDB) dB, "
                      + "\(plan.spans.count) spans, \(plan.removed.count) stretches taken out, \(plan.checks.count) checks, \(words.words.count) words, "
                      + "transcript \(plan.transcriptSHA256.prefix(12))..., file \(planData.count) bytes")
        for kind in RemovedKind.allCases where plan.count(kind) > 0 {
            let seconds = plan.removed.filter { $0.kind == kind }.reduce(0) { $0 + $1.to - $1.from }
            report.append("  \(kind.rawValue): \(plan.count(kind)), \(String(format: "%.2f", seconds)) s")
        }
        for item in plan.removed where item.kind != .pause {
            report.append("  \(TimeText.string(item.from)) to \(TimeText.string(item.to)) \(item.kind.rawValue)\(item.clean ? "" : " (not clean)"): \(item.say)")
        }
        for check in plan.checks { report.append("  check: \(check.say)") }

        // 2. Measured against the original's own sound.
        let scratch = FileManager.default.temporaryDirectory.appending(path: "accept-video-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let samples = try await PlanMeasure.decode(talk13, scratch: scratch)
        report += measure(plan, words: words, samples: samples, verdict: verdict)

        // 3. Make Again plans again by itself, and the plan is the same.
        let firstModified = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: planURL.path)[.modificationDate] as? Date)
        try await Task.sleep(for: .seconds(1.1))
        await model.runner.process(recording, trigger: .makeAgain)
        XCTAssertEqual(recording.status, .readyForYourYes, recording.statusReason ?? "")
        let step = recording.latestRun?.steps.first { $0.name == PipelineStep.planEdit.title }
        let again = try XCTUnwrap(EditPlan.decode(Data(contentsOf: planURL)))
        let secondModified = try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: planURL.path)[.modificationDate] as? Date)
        verdict("Make Again plans again (step \"Planning the edit\")", step?.state == .done && secondModified > firstModified,
                "step \(step?.state.rawValue ?? "absent"): \(step?.detail ?? "") (\(String(format: "%.1f", step?.seconds ?? -1)) s)")
        verdict("The same plan both times", again.spans == plan.spans && again.removed == plan.removed && again.checks == plan.checks,
                "\(again.spans.count) and \(plan.spans.count) spans, \(again.removed.count) and \(plan.removed.count) removed")

        // 4. The 6 Sep talk, planned from its development transcript (no make), measured the same way.
        let folder06 = paths.outputs.appending(path: "2026-09-06 18-06-33", directoryHint: .isDirectory)
        let transcript06 = folder06.appending(path: TranscriptFiles.asHeard)
        if FileManager.default.fileExists(atPath: transcript06.path) {
            // What the 6 Sep folder holds before (a `make accept-video` before this one leaves its own edit-plan.json there):
            // planning here must not add or change a file in it.
            let planFile06 = folder06.appending(path: EditPlan.fileName)
            let planBefore06 = fingerprint(planFile06)
            let ffmpeg = ToolPaths.standard.ffmpeg
            let probe = try await Subprocess.run(ToolPaths.standard.ffprobe, ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", talk06.path],
                                                 timeout: .seconds(60))
            let duration06 = try XCTUnwrap(Double(probe.stdout.trimmingCharacters(in: .whitespacesAndNewlines)))
            let setup = PlanStep.Setup(original: talk06, transcript: transcript06, jobFolder: scratch.appending(path: "plan06", directoryHint: .isDirectory),
                                       duration: duration06, frameRate: await PlanStep.frameRate(of: talk06, ffprobe: ToolPaths.standard.ffprobe))
            let outcome = try await PlanStep.run(setup, now: Date()) { arguments in
                _ = try await Subprocess.run(ffmpeg, arguments, captureStdout: false, timeout: .seconds(900))
            }
            let words06 = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: transcript06)))
            report += ["", "6 Sep talk (planned from ~/Prakriti/Dev/Outputs/2026-09-06 18-06-33/transcript.json, nothing written there): "
                       + outcome.plan.summary + String(format: " Planned in %.1f s.", outcome.seconds)]
            let samples06 = try await PlanMeasure.decode(talk06, scratch: scratch)
            report += measure(outcome.plan, words: words06, samples: samples06, verdict: { name, pass, measured in verdict("6 Sep: " + name, pass, measured) })
            XCTAssertEqual(fingerprint(planFile06), planBefore06, "nothing written into the 6 Sep folder")
        } else {
            report.append("6 Sep talk: SKIPPED, no development transcript at \(transcript06.path)")
        }

        // The originals were only read.
        let after = [talk13, talk06].map(fingerprint)
        verdict("Originals unchanged (size and modification date)", after == before, after == before ? "unchanged" : "CHANGED")

        let lines = verdicts.map { "\($0.1 ? "PASS" : "FAIL")  \($0.0): \($0.2)" }
        let text = (["v2 part M8a acceptance (the edit plan)", ""] + lines + ["", "Details", ""] + report).joined(separator: "\n") + "\n"
        let out = SnapshotRenderer.milestoneFolder()
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try text.write(to: out.appending(path: "acceptance-video.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M8a finished.")
    }

    /// The plan's measured checks, as report lines; each gate goes to `verdict`.
    private func measure(_ plan: EditPlan, words: PlanWords, samples: [Float], verdict: (String, Bool, String) -> Void) -> [String] {
        var lines: [String] = []
        let m = PlanMeasure(plan: plan, words: words, samples: samples, envelope: Envelope.of(samples: samples))
        let frame = plan.frameDuration

        // Cut points.
        // A cut point passes when it is 20 dB or more under speech for the 20 ms around it, "or inside a crossfade"
        // (PLAN M8 check 2): the one kind of cut placed on purpose where it is not that quiet is a stutter said with no gap,
        // which the plan marks not clean, cuts at the dip before the second copy, and M8b joins with a 20 ms crossfade.
        // Those are counted and listed apart, so a reader sees each one; any other cut under 20 dB fails.
        let cuts = m.cutPoints
        let loud = cuts.filter { $0.under < Envelope.quietUnderSpeech }
        let stutterJoins = loud.filter { $0.kind == .stutter && !$0.clean && $0.under >= RoughCutPreset.clear.stutterDip }
        let failing = loud.filter { c in !stutterJoins.contains { $0.at == c.at } }
        let quietest = cuts.map(\.under).min() ?? 0
        verdict("Every cut point 20 dB or more under speech for 20 ms, or a marked stutter join inside its crossfade", failing.isEmpty,
                "\(cuts.count) cut points, \(cuts.count - loud.count) at 20 dB or more under speech (\(String(format: "%.1f", m.envelope.speech)) dBFS), "
                + "\(stutterJoins.count) stutter joins under it"
                + (stutterJoins.isEmpty ? "" : " (" + stutterJoins.map { "\(TimeText.string($0.at)) at \(String(format: "%.1f", $0.under)) dB" }.joined(separator: ", ") + ")")
                + ", \(failing.count) other; the least quiet \(String(format: "%.1f", quietest)) dB under"
                + (failing.isEmpty ? "" : ": " + failing.prefix(10).map { "\(TimeText.string($0.at)) \($0.kind.rawValue) \(String(format: "%.1f", $0.under))" }.joined(separator: ", ")))

        // What a pause or trim takes out must be silence, not words Parakeet did not write (v2 part M8b, fixes after the
        // verifier: on 6 Sep two 17 s "pauses" held 93 words). Measured on the original's own 10 ms levels: the time in each
        // such stretch louder than 20 dB under speech.
        let env = m.envelope
        let soundTaken = plan.removed.filter { $0.kind == .pause || $0.kind == .trimmed }.map { item -> (EditPlan.Item, Double) in
            let a = max(0, env.frameIndex(item.from)), b = min(env.levels.count, env.frameIndex(item.to))
            let loudFrames = a < b ? env.levels[a..<b].filter { $0 > env.quietLevel }.count : 0
            return (item, Double(loudFrames) * Envelope.frame)
        }
        let soundy = soundTaken.filter { $0.1 > RoughCut.soundAllowed + 0.0001 }
        verdict("No pause or trim takes out sound (at most 0.25 s louder than 20 dB under speech in each)", soundy.isEmpty,
                "\(soundTaken.count) pauses and trims, the most sound in one \(String(format: "%.2f", soundTaken.map(\.1).max() ?? 0)) s"
                + (soundy.isEmpty ? "" : ": " + soundy.prefix(10).map { "\(TimeText.string($0.0.from)) to \(TimeText.string($0.0.to)) holds \(String(format: "%.2f", $0.1)) s" }.joined(separator: "; ")))

        // Pauses: silences in the edit.
        let silences = m.silences(longer: 0.40)
        var leading = 0.0
        var tooLong: [String] = []
        var protectedKept = 0
        var insideSound: [String] = []
        let planWord = Dictionary(plan.words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for s in silences {
            guard let after = s.after else { leading = s.length; continue }
            let word = words.words[after]
            let isProtected = RoughCut.isProtected(after: after, words: words.words)
            let trigger = word.closes == .none ? 0.40 : 0.60
            let atEnd = s.at + s.length >= plan.keptSeconds - 0.05
            if atEnd { continue }
            // A silence inside a gap Parakeet wrote no word for though it holds sound (warning 148) is not a pause between two
            // words: the plan keeps the sound and may shorten only one quiet stretch of it. Counted apart, never hidden.
            // The gap as the plan placed its words (their times moved onto the sound), not Parakeet's raw times.
            let gapStart = planWord[word.id]?.out ?? word.end
            let gapEnd = after + 1 < words.words.count ? (planWord[words.words[after + 1].id]?.in ?? words.words[after + 1].start) : plan.sourceDuration
            let gapSound = RoughCut.LoudCount(envelope: env, from: gapStart, to: gapEnd).seconds(gapStart, gapEnd)
            if s.length > trigger + 0.005 && gapSound > RoughCut.soundAllowed {
                insideSound.append("\(TimeText.string(s.original)) \(String(format: "%.2f", s.length)) s (the gap holds \(String(format: "%.1f", gapSound)) s of sound)")
            } else if s.length > trigger + 0.005 {
                if isProtected { protectedKept += 1 } else { tooLong.append("\(TimeText.string(s.original)) \(String(format: "%.2f", s.length)) s after \"\(word.text)\"") }
            }
        }
        verdict("No silence in the edit over the trigger except protected ones", tooLong.isEmpty && leading <= RoughCutPreset.clear.keepBeforeFirst + frame.seconds + 0.01,
                "\(tooLong.count) over (0.60 s after punctuation, 0.40 s inside a sentence), \(protectedKept) protected kept, opening silence \(String(format: "%.2f", leading)) s"
                + (tooLong.isEmpty ? "" : ": " + tooLong.prefix(10).joined(separator: "; "))
                + (insideSound.isEmpty ? "" : "; \(insideSound.count) longer inside sound Parakeet wrote no words for, kept: " + insideSound.prefix(10).joined(separator: "; ")))
        let pauses = m.pauses
        let shortenedSentence = pauses.filter { $0.closes != .none && $0.shortened && !$0.protected }
        let shortenedInside = pauses.filter { $0.closes == .none && $0.shortened && !$0.protected }
        let sentenceMedian = PlanMeasure.median(shortenedSentence.map(\.now))
        let insideMedian = PlanMeasure.median(shortenedInside.map(\.now))
        let allSentence = PlanMeasure.median(pauses.filter { $0.closes == .sentence || $0.closes == .question }.map(\.now))
        verdict("Median shortened sentence pause within 50 ms of 0.35 s", sentenceMedian.map { abs($0 - 0.35) <= 0.05 } ?? true,
                "\(shortenedSentence.count) shortened, median \(sentenceMedian.map { String(format: "%.3f", $0) } ?? "none"); inside a sentence \(shortenedInside.count), median "
                + "\(insideMedian.map { String(format: "%.3f", $0) } ?? "none") (target 0.18); every pause after a full stop or question, median "
                + "\(allSentence.map { String(format: "%.3f", $0) } ?? "none") (none is ever lengthened)")

        // Kept length and sync: spans and cuts on frames.
        let offGrid = plan.spans.filter { !frame.isBoundary($0.in) || (!frame.isBoundary($0.out) && abs($0.out - frame.below(plan.sourceDuration)) > 1e-6) }
        let offGridCuts = plan.removed.filter { !frame.isBoundary($0.from) || (!frame.isBoundary($0.to) && abs($0.to - plan.sourceDuration) > 1e-6) }
        let frames = plan.spans.reduce(0.0) { $0 + ($1.out - $1.in) / frame.seconds }
        verdict("Kept length is the sum of spans, a whole number of frames", offGrid.isEmpty && abs(frames - frames.rounded()) < 1e-3 && abs(plan.keptSeconds - frames.rounded() * frame.seconds) < 1e-3,
                "\(plan.spans.count) spans, \(String(format: "%.3f", frames)) frames of \(frame) = \(String(format: "%.3f", plan.keptSeconds)) s, \(offGrid.count) off a frame")
        verdict("Picture and sound cut on the same frame", offGridCuts.isEmpty, "\(plan.removed.count) stretches, \(offGridCuts.count) cut off a frame boundary")
        // Every second of the original is either kept in a span or taken out by a listed removal, so nothing leaves the edit
        // without a reason Ivan can see (a stretch with no word in it once fell between the spans unlisted).
        let listed = plan.removed.reduce(0.0) { $0 + $1.to - $1.from }
        let unaccounted = plan.sourceDuration - plan.keptSeconds - listed
        verdict("Every second is kept or taken out by a listed removal", abs(unaccounted) <= frame.seconds + 0.001,
                String(format: "source %.3f s = kept %.3f s + removed %.3f s, %.3f s unaccounted (one frame %.4f s)",
                       plan.sourceDuration, plan.keptSeconds, listed, unaccounted, frame.seconds))

        // Reported only: joins and filler recall.
        let joins = m.joins
        let over = joins.filter { $0.jump > $0.around }
        let worst = joins.map { Double($0.jump / max($0.around, 1e-9)) }.max() ?? 0
        lines.append("Joins made as M8b will (20 ms equal-power crossfade), not gated in M8a: \(joins.count) joins, \(over.count) whose largest jump is over the largest "
                     + "in the original's 50 ms around the cuts, the worst \(String(format: "%.2f", worst)) times it; the loudest of those jumps "
                     + "\(String(format: "%.1f", 20 * log10(Double(over.map(\.jump).max() ?? 1e-9)))) dBFS")
        let fillers = words.words.filter { ["um", "uh"].contains($0.norm) }
        let removed = Set(plan.removed.filter { $0.kind == .filler }.flatMap { item -> [Int] in
            guard let ids = item.words, let a = ids.first.flatMap(PlanWord.index(of:)), let b = ids.last.flatMap(PlanWord.index(of:)) else { return [] }
            return Array(a...b)
        })
        lines.append("Fillers: the transcript has \(fillers.count) \"um\" and \"uh\"; the plan takes out \(fillers.filter { removed.contains($0.index) }.count). "
                     + "The rest sit with no quiet around them and are kept (research 1.5: never cut what cannot be cut cleanly).")
        lines.append("Removed in all: \(String(format: "%.1f", plan.sourceDuration - plan.keptSeconds)) s of \(String(format: "%.1f", plan.sourceDuration)) s.")
        // The experiment for Ivan's choice, not shipped: fillers cut in the dips around them (`RoughCutPreset.fillerDip`).
        for under in [12.0, 6.0] {
            var preset = RoughCutPreset.clear
            preset.fillerDip = under
            let input = RoughCut.Input(words: words, envelope: m.envelope, duration: plan.sourceDuration, frame: frame, edits: plan.basis.edits,
                                       leftOut: plan.people.cuts, preset: preset)
            let trial = RoughCut.make(input)
            let taken = Set(trial.removed.filter { $0.kind == .filler }.flatMap { $0.words.map(Array.init) ?? [] })
            let dipCuts = trial.removed.filter { $0.kind == .filler && !$0.clean }
            lines.append("If fillers were cut in a dip \(Int(under)) dB under speech (not shipped): \(fillers.filter { taken.contains($0.index) }.count) of \(fillers.count) "
                         + "\"um\" and \"uh\" out, \(dipCuts.count) of those cuts under 20 dB, \(String(format: "%.1f", plan.sourceDuration - trial.keptSeconds)) s out in all.")
        }
        return lines
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
