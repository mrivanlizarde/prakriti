import AVFoundation
import CoreImage
import Foundation
import SwiftData
import SwiftUI
import Vision
import XCTest
@testable import Prakriti

/// v2 part M12b's acceptance (docs/v2/PLAN.md M12, checks 2 (add, Make Again), 3, 5 (Timeline-lite) and 7), through the app in development,
/// on the whole talks (M12b is the last part of M12, PLAN 14 Oct):
///
/// - check 2: the REAL 13 Sep and 6 Sep talks made in development (transcript and people check), both "Who is teaching: Gabriel Galindo";
///   Find Supporting Moments on 13 Sep for the part about Gabriel's own sales career (selected words, as M12a found 3 there); Add on the
///   first; the edited video switched on; Make Again;
/// - check 3, in the new 13 Sep video: Parakeet run again on the moment's stretch hears its words, the first at the planned time within
///   0.5 s; Vision reads "6 Sep 2026" in the frame 1 s into the moment (the frame written for Ivan to look at; never looked at here, PLAN
///   section 11 D1); each joined recording within 1 LU of -14 LUFS; the plan validates against both recordings; the Ready checklist passes;
/// - check 5: the Timeline-lite of the made plan drawn (bars and a teal span only, no picture of anyone);
/// - check 7: a face planted in the corner of the 6 Sep people file inside the moment, an unnamed person set to Leave Out there: Make Again
///   on 13 Sep is refused with PLAN M12's line and nothing new reaches Video/. The 6 Sep people file is put back afterwards.
///
///   cd ~/Code/prakriti/mac && make accept-merge MILESTONE=v2-m12b PRAKRITI_MERGE_PART=add
///
/// Skipped unless PRAKRITI_ACCEPTANCE=merge (and PRAKRITI_MERGE_PART is "add" or empty). The store is in memory; outputs go to
/// ~/Prakriti/Dev/Outputs; the originals are only read, checked by size and date before and after. Never a class, never the archive. Every
/// model request goes to LM Studio (a refusing cloud client counts any other).
@MainActor
final class MergeAddAcceptanceTests: XCTestCase {
    func testAddTheFirstMomentAndMakeAgain() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "merge", (environment["PRAKRITI_MERGE_PART"] ?? "") != "find" else {
            throw XCTSkip("Reads the 13 Sep and 6 Sep talks. Run it with: cd ~/Code/prakriti/mac && make accept-merge MILESTONE=v2-m12b PRAKRITI_MERGE_PART=add")
        }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)
        func report() {
            let text = (["v2 part M12b acceptance (supporting moments, added), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                        + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed."]).joined(separator: "\n") + "\n"
            try? text.write(to: out.appending(path: "acceptance-merge-add.txt"), atomically: true, encoding: .utf8)
            print(text)
        }

        let paths = AppPaths(mode: .development)
        let talks = [("13 Sep", paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")),
                     ("6 Sep", paths.studioRecordings.appending(path: "2026-09-06/2026-09-06 18-06-33.mp4"))]
        for (_, url) in talks {
            XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { url.path.contains($0) }, "never a class")
        }
        let before = talks.map { fingerprint($0.1) }

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        for task in ModelTask.allCases { model.settings.provider[task] = .lmStudio }
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        model.log.write("Acceptance test for v2 part M12b (supporting moments, added) started.")
        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        try model.context.save()

        // Check 2: both talks made in development, Gabriel teaching.
        var recordings: [String: Recording] = [:]
        for (label, url) in talks {
            let recording = Recording(filePath: url.path, recordedAt: AppModel.dateInName(url.lastPathComponent), foundAt: Date())
            model.context.insert(recording)
            recording.source = model.source(containing: url)
            recording.kind = .talk
            try model.context.save()
            model.setTeacher(teacher, for: recording)
            let started = Date()
            await model.runner.process(recording, trigger: .byHand)
            lines.append(String(format: "%@: made in development in %.0f s; people checked: %@", label, Date().timeIntervalSince(started),
                                recording.peopleFacts.checked ? "yes" : "no"))
            recordings[label] = recording
        }
        guard let sep13 = recordings["13 Sep"], let sep6 = recordings["6 Sep"], let folder13 = sep13.outputFolder.map({ URL(fileURLWithPath: $0, isDirectory: true) }),
              sep6.outputFolder != nil, sep13.peopleFacts.checked, sep6.peopleFacts.checked else {
            verdict("Check 2: both talks made and their people checked", false, "not made")
            report()
            return
        }
        precondition(folder13.path.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        let words13 = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folder13.appending(path: TranscriptFiles.asHeard))))
        if let cached = BeatsCache.seed("2026-09-13 18-25-44", folder: folder13) {
            lines.append("13 Sep parts of the talk from the cache: \(cached.line)")
        }
        let beats13 = try XCTUnwrap(BeatsFile.cached(in: folder13, transcriptSHA256: words13.transcriptSHA256), "the 13 Sep parts of the talk")

        // Find Supporting Moments for the part about the sales career (selected words), then Add on the first.
        guard let part = beats13.beats.first(where: { $0.summary.lowercased().contains("sales") }) else {
            verdict("Check 2: a part of 13 Sep about sales to select", false, beats13.beats.map(\.summary).joined(separator: "; "))
            report()
            return
        }
        var started = Date()
        let state = await model.searchMoments(MomentsRequest(recordingID: sep13.id, selection: TimeRange(start: part.start, end: part.end)))
        guard case .found(let search) = state, let first = search.moments.first else {
            verdict("Check 2: Find Supporting Moments gives one to three moments from 6 Sep", false, "\(state)")
            report()
            return
        }
        lines.append(String(format: "Find Supporting Moments on 13 Sep for \u{201C}%@\u{201D} (%@ to %@): %.0f s, %d found by %@.", part.summary, Format.timecode(part.start),
                            Format.timecode(part.end), Date().timeIntervalSince(started), search.moments.count, search.by))
        verdict("Check 2: one to three moments, all from 6 Sep", (1...3).contains(search.moments.count) && search.moments.allSatisfy { $0.sourceID == sep6.id },
                search.moments.map { "\($0.sourceLabel) at \(Format.timecode($0.window.start)), \(Format.timecode($0.seconds))" }.joined(separator: "; "))
        XCTAssertTrue(sep13.direction.moments.isEmpty, "the search added nothing")
        verdict("Check 1: nothing is added by the search itself", sep13.direction.moments.isEmpty, "\(sep13.direction.moments.count) moments kept before Add")
        model.addMoment(first, to: sep13)
        let added = try XCTUnwrap(sep13.direction.moments.first)
        lines.append("Added the first: \(first.sourceLabel), \(Format.timecode(first.window.start)) to \(Format.timecode(first.window.end)) of 6 Sep (\(Format.timecode(first.seconds))), after \u{201C}...\(first.afterWords)\u{201D} at \(Format.timecode(first.after)).")
        lines.append("  Words: \u{201C}\(first.words)\u{201D}")
        verdict("Check 1: the added moment carries addedBy \"ivan\"", added.addedBy == "ivan" && sep13.direction.moments.count == 1, "addedBy \(added.addedBy)")

        // Make Again with the edited video on (Clear, the House Style).
        model.setOutput(.editedVideo, on: true, for: sep13)
        started = Date()
        await model.runner.process(sep13, trigger: .byHand)
        let makeSeconds = Date().timeIntervalSince(started)
        guard let record = sep13.video, let plan = EditPlan.read(folder: folder13.path) else {
            verdict("Check 2: Make Again made the 13 Sep video with the moment", false, sep13.videoProblem ?? sep13.statusReason ?? "no video")
            report()
            return
        }
        lines.append("")
        lines.append(String(format: "Make Again on 13 Sep: %.0f s. %@", makeSeconds, plan.summary))
        for line in plan.planLines ?? [] { lines.append("  Plan: " + line) }
        let inserts = model.momentInserts(for: sep13)
        let span = try XCTUnwrap(plan.insertSpans.first, "the plan holds the moment")
        verdict("Check 2: the plan holds the moment as an insert span added by Ivan, the 6 Sep transcript's own words",
                plan.insertSpans.count == 1 && span.addedBy == "ivan" && span.source == "2026-09-06 18-06-33"
                    && PlanWords.comparable(span.text) == PlanWords.comparable(first.words),
                "span \(span.id), \(span.source), addedBy \(span.addedBy ?? "none"), \(span.text.split(separator: " ").count) words, join \(span.join ?? 0) frames, colour \(span.colour.map { $0.map { String(format: "%.3f", $0) }.joined(separator: " ") } ?? "none")")
        let problems = PlanValidation.check(plan, words: words13, inserts: inserts)
        verdict("Check 3: the plan validates (every rule, the moment against the 6 Sep recording as it is now)", problems.isEmpty,
                problems.map(\.line).joined(separator: "; ").isEmpty ? "no problem" : problems.map(\.line).joined(separator: "; "))
        verdict("Check 3: the Ready checklist passes", record.failed == 0,
                record.summary + (record.failed > 0 ? ": " + record.checklist.filter { $0.status == .fail }.map(\.text).joined(separator: "; ") : ""))

        let timeline = EditTimeline(plan: plan)
        let piece = try XCTUnwrap(timeline.pieces.first { $0.id == span.id })
        let start = timeline.seconds(piece.editFrame), end = timeline.seconds(piece.editFrame + piece.frames)
        let mp4 = folder13.appending(path: VideoStep.folderName).appending(path: record.fileName)
        lines.append(String(format: "The moment in the video: %@ to %@ (%.2f s), the video %@ long.", Format.timecode(start), Format.timecode(end), end - start,
                            Format.timecode(timeline.duration)))

        // Check 3: Parakeet hears the added words at the planned time.
        let scratch = FileManager.default.temporaryDirectory.appending(path: "m12b-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let wav = scratch.appending(path: "moment.wav")
        let from = max(0, start - 2)
        try run(ToolPaths.standard.ffmpeg, ["-y", "-v", "error", "-ss", String(format: "%.3f", from), "-t", String(format: "%.3f", end - start + 4), "-i", mp4.path,
                                            "-vn", "-ac", "1", "-ar", "16000", wav.path])
        try run(ToolPaths.standard.parakeet, [wav.path, "--output-dir", scratch.path, "--output-format", "all", "--output-template", "{filename}"])
        // Filler words ("uh", "um") are left out on both sides: Parakeet writes them or not from one run to the next, so the first word
        // compared is the moment's first real word, at its own planned time.
        let fillers: Set<String> = ["uh", "um", "uhm", "mm", "hmm", "er", "erm", "ah"]
        let heard = ((try? Data(contentsOf: scratch.appending(path: "moment.json"))).flatMap(PlanWords.from(json:))?.words ?? [])
            .map { (norm: $0.norm, start: $0.start + from) }.filter { !fillers.contains($0.norm) }
        let saidAll = zip(span.text.split(separator: " ").map { PlanWord.normalize(String($0)) }, span.words ?? []).filter { !$0.0.isEmpty && !fillers.contains($0.0) }
        let said = saidAll.map(\.0)
        let plannedFirst = timeline.editTime(saidAll.first?.1.in ?? span.in, span: span.id) ?? start
        // The first three words said, in order, in what was heard.
        var heardAt: Double?
        if said.count >= 3 {
            for i in heard.indices where i + 2 < heard.count && heard[i].norm == said[0] && heard[i + 1].norm == said[1] && heard[i + 2].norm == said[2] {
                heardAt = heard[i].start
                break
            }
        }
        let inOrder = Self.longestInOrder(said, heard.map(\.norm))
        verdict("Check 3: Parakeet run again hears the added words at the planned time within 0.5 s",
                heardAt.map { abs($0 - plannedFirst) <= 0.5 } == true && Double(inOrder) >= 0.9 * Double(said.count),
                String(format: "first words planned at %@ (%.2f s), heard at %@; %d of %d of its words heard in order", Format.timecode(plannedFirst), plannedFirst,
                       heardAt.map { String(format: "%.2f s", $0) } ?? "never", inOrder, said.count))

        // Check 3: the date label 1 s into the moment, read by Vision. The frame is written for Ivan, never looked at here.
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: mp4))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let at = start + 1
        let image = try await generator.image(at: CMTime(seconds: at, preferredTimescale: 30000)).image
        var text = RecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = false
        // The label is small by design (34 px of 1080): read in the top corner it sits in, at twice its size, with no smallest height.
        // Measured 16 Oct: on the whole frame Vision read nothing there, while 648 pixels of the label's box were white and none beside it.
        text.minimumTextHeightFraction = 0
        let corner = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 0, width: image.width / 3, height: image.height / 4)))
        let read = try await text.perform(on: Self.doubled(corner)).compactMap { $0.topCandidates(1).first?.string }
        let picture = forIvan.appending(path: "13sep-moment-date-label-1s.png")
        try MergeAddTests.png(image, to: picture)
        verdict("Check 3: the date label \u{201C}6 Sep 2026\u{201D} is in the frame 1 s into the moment (Vision text recognition)",
                read.contains { $0.contains("6 Sep 2026") }, "read \(read.filter { $0.contains("Sep") || $0.contains("2026") }) at \(String(format: "%.2f", at)) s; picture for Ivan: \(picture.path)")

        // Check 3: each joined recording within 1 LU of the target.
        let target = VideoAudio.target
        let mine1 = try await MergeAddTests.loudness(mp4, from: 0.5, to: start - 0.4)
        let theirs = try await MergeAddTests.loudness(mp4, from: start + 0.4, to: end - 0.4)
        let mine2 = try await MergeAddTests.loudness(mp4, from: end + 0.4, to: timeline.duration - 5.5)
        verdict("Check 3: each joined recording measures within 1 LU of the target (\(Int(target)) LUFS)",
                [mine1, theirs, mine2].allSatisfy { abs($0 - target) <= 1 },
                String(format: "13 Sep before the moment %.1f LUFS, the 6 Sep moment %.1f LUFS, 13 Sep after it %.1f LUFS", mine1, theirs, mine2))

        // Check 5: the Timeline-lite of the made plan (bars only, no picture of anyone), drawn to look at.
        let spans = TimelineSpan.spans(plan: plan)
        verdict("Check 5: the Timeline-lite holds one teal moment where it goes", spans.filter(\.isMoment).count == 1,
                spans.filter(\.isMoment).map(\.line).joined(separator: "; "))
        let renderer = try SnapshotRenderer(outputFolder: out)
        for (scheme, appearance) in SnapshotRenderer.appearances {
            let view = VStack(alignment: .leading, spacing: 12) {
                Text("13 Sep, the edit plan with the moment from 6 Sep").font(AppFont.headline)
                TimelineLite(spans: spans, marks: TimelineMark.marks(plan: plan), duration: plan.sourceDuration, position: nil, selected: nil) { _ in }
            }
            .padding(24)
            try renderer.renderSheet(AnyView(view.frame(width: 900, height: 140)), model: model, size: CGSize(width: 900, height: 172), appearance: appearance,
                                     name: "30-timeline-lite-13sep-\(scheme)")
        }

        // Check 7: a face planted in the corner of the 6 Sep people file inside the moment, an unnamed person on Leave Out.
        lines.append("")
        let folders = model.peopleFolders
        let file6 = folders.peopleFile(for: sep6.id)
        let saved = try Data(contentsOf: file6)
        var people6 = try XCTUnwrap(folders.read(sep6.id))
        let row = (people6.people.map(\.id).max() ?? 0) + 1
        let track = (people6.tracks.map(\.id).max() ?? 0) + 1
        let t0 = first.window.start + 2, t1 = min(first.window.end, t0 + 4)
        people6.tracks.append(PeopleFile.Track(id: track, person: row, start: t0, end: t1, boxes: stride(from: t0, through: t1, by: 0.5).map { [$0, 0.86, 0.06, 0.08, 0.14, 0.9] }))
        people6.people.append(FacePerson(id: row, label: "Unnamed \(row)", onScreen: t1 - t0, first: t0, last: t1, appearances: 1, keyTime: t0,
                                         keyBox: FaceBox(x: 0.86, y: 0.06, width: 0.08, height: 0.14)))
        try PeopleFile.encoder.encode(people6).write(to: file6, options: .atomic)
        var choices6 = sep6.choices
        choices6.set(.leaveOut, for: .face(row))
        let savedChoices = sep6.choicesJSON
        sep6.choices = choices6
        try model.context.save()
        defer {
            try? saved.write(to: file6, options: .atomic)
            sep6.choicesJSON = savedChoices
            try? model.context.save()
        }
        let videoFolder = folder13.appending(path: VideoStep.folderName)
        let listing = { () -> [String] in
            ((try? FileManager.default.contentsOfDirectory(at: videoFolder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []).map {
                "\($0.lastPathComponent) \((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSince1970) ?? 0)"
            }.sorted()
        }
        let beforeRefusal = listing()
        let line = "A moment from Sun 6 Sep now includes someone who is hidden. Remove it or change their choice."
        let refusal = MomentInserts.refusal(model.momentInserts(for: sep13)[0])
        started = Date()
        await model.runner.process(sep13, trigger: .byHand)
        let afterRefusal = listing()
        let newer = afterRefusal.filter { !beforeRefusal.contains($0) }
        let problem = sep13.videoProblem ?? ""
        lines.append(String(format: "Make Again on 13 Sep with the planted corner face on Leave Out in 6 Sep: %.0f s. The video step said: %@", Date().timeIntervalSince(started), problem))
        verdict("Check 7: Make Again on 13 Sep is refused with PLAN M12's line", refusal == line && problem.contains(line) && sep13.video == nil,
                "refusal \u{201C}\(refusal ?? "none")\u{201D}; the video step: \u{201C}\(problem)\u{201D}")
        verdict("Check 7: nothing new reaches Video/", newer.isEmpty,
                "before \(beforeRefusal.count) files, after \(afterRefusal.count); new or changed: \(newer.isEmpty ? "none" : newer.joined(separator: ", "))"
                    + (afterRefusal.isEmpty ? " (the make took the old video out, which held the moment)" : ""))
        verdict("Check 4 (still): no request reached a cloud provider", cloudCalls.count == 0, "the refusing cloud client was asked \(cloudCalls.count) times")

        let after = talks.map { fingerprint($0.1) }
        verdict("The originals are unchanged by size and date", before == after, after.joined(separator: "; "))
        report()
        model.log.write("Acceptance test for v2 part M12b finished.")
    }

    /// A picture at twice its size (Lanczos), for reading small text.
    static func doubled(_ image: CGImage) -> CGImage {
        let ci = CIImage(cgImage: image).applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 2.0, kCIInputAspectRatioKey: 1.0])
        return CIContext().createCGImage(ci, from: ci.extent) ?? image
    }

    /// The longest run of `a` found in order in `b`.
    static func longestInOrder(_ a: [String], _ b: [String]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var row = [Int](repeating: 0, count: b.count + 1)
        for x in a {
            var previous = 0
            for j in 1...b.count {
                let saved = row[j]
                row[j] = x == b[j - 1] ? previous + 1 : max(row[j], row[j - 1])
                previous = saved
            }
        }
        return row[b.count]
    }

    private func run(_ tool: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = ToolPaths.searchPath + ":" + (environment["PATH"] ?? "")
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
