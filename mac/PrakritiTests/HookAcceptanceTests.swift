import AVFoundation
import Foundation
import Synchronization
import SwiftData
import Vision
import XCTest
@testable import Prakriti

/// v2 part M9d's acceptance (docs/v2/PLAN.md M9, checks 3 for Clear in full, 4 at every text moment, and 6), on the REAL 13 Sep
/// talk, whole, made in development through the app's runner with the edited video on, a test title in Info and Gabriel named as
/// teaching (development store only), the House Style at its standard (Clear, key phrases Subtle, terms and the opening line on),
/// and the parts of the talk from Qwen3.8-27B in LM Studio (read from `BeatsCache` when they were made from this very transcript
/// with this request, else asked for and timed):
///
/// - check 3, Clear in full: every visual change counted (cuts, changes of framing and every text coming in), 6 to 8 a minute and
///   10 or more in the first 30 s; every punch-in at most 1.15; every text on screen equal to the transcript's words for its range
///   (key phrases, terms and the opening line; the title and the name are Ivan's own words); chapters by YouTube's rules; the held
///   moment one still shot; speech ending 5 s before the last frame;
/// - check 4, at every text moment: the made frame against the same frame drawn without text, every 0.5 s of each text's life, the
///   text's pixels inside title safe and clear of every face Vision finds (numbers only; frames written for Ivan);
/// - check 6: made again with "More energetic. Faster, more frequent cuts." (version 2); Play switches the Viewer between versions 1
///   and 2 (the player item's length and plan are each version's); Approve (into the development Approved folder) names version 2,
///   in its question and its receipt.
///
///   cd ~/Code/prakriti/mac && make accept-hook MILESTONE=v2-m9d
///
/// Skipped unless PRAKRITI_ACCEPTANCE=hook. The store is in memory; outputs go to ~/Prakriti/Dev/Outputs; the original is only read,
/// checked by size and date before and after. Never a class, never the archive. Nothing goes to a cloud provider: planning is set to
/// LM Studio and the cloud client factory refuses.
@MainActor
final class HookAcceptanceTests: XCTestCase {
    func testHookChaptersAndVersionsOnTheThirteenthOfSeptember() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PRAKRITI_ACCEPTANCE"] == "hook" else {
            throw XCTSkip("Reads the 13 Sep talk. Run it with: cd ~/Code/prakriti/mac && make accept-hook MILESTONE=v2-m9d")
        }
        var lines: [String] = []
        var failures = 0
        func verdict(_ name: String, _ pass: Bool, _ measured: String) {
            lines.append("\(pass ? "PASS" : "FAIL")  \(name): \(measured)")
            if !pass { failures += 1 }
            XCTAssertTrue(pass, "\(name): \(measured)")
        }
        let paths = AppPaths(mode: .development)
        let talk = paths.studioRecordings.appending(path: "2026-09-13/2026-09-13 18-25-44.mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: talk.path), "missing: \(talk.path)")
        XCTAssertFalse(["2026-09-14", "2026-09-16", "2026-09-20", "2026-09-23"].contains { talk.path.contains($0) }, "never a class")
        let before = fingerprint(talk)
        let out = SnapshotRenderer.milestoneFolder()
        let forIvan = out.appending(path: "for-ivan", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: forIvan, withIntermediateDirectories: true)

        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(), log: AppLog(directory: paths.logs), now: Date.init)
        _ = try PrakritiStore.seedIfEmpty(model.context, paths: paths, now: Date())
        model.runner.stableWait = .seconds(2)
        model.settings.provider[.planning] = .lmStudio
        let counted = Mutex<[CountingClient]>([])
        model.runner.makeClient = { provider, setup in
            let client = CountingClient(WritingSetup.standardClient(provider, setup))
            counted.withLock { $0.append(client) }
            return client
        }
        let cloudCalls = CallCounter()
        model.runner.makeCloudClient = { provider, _ in RefusingClient(provider: provider, counter: cloudCalls) }
        func requests() -> Int { counted.withLock { $0.reduce(0) { $0 + $1.requests } } }
        XCTAssertEqual(model.settings.houseStyle, .standard)
        model.log.write("Acceptance test for v2 part M9d (hook, chapters, versions) started.")

        let teacher = Person(name: "Gabriel Galindo")
        teacher.role = .teacher
        model.context.insert(teacher)
        let recording = Recording(filePath: talk.path, recordedAt: AppModel.dateInName(talk.lastPathComponent), foundAt: Date())
        model.context.insert(recording)
        recording.source = model.source(containing: talk)
        recording.kind = .talk
        recording.title = TextAcceptanceTests.testTitle
        try model.context.save()
        model.setTeacher(teacher, for: recording)
        model.setOutput(.editedVideo, on: true, for: recording)
        // The parts of the talk: from the cache when they were made from this very transcript, else asked for here.
        let name = talk.deletingPathExtension().lastPathComponent
        let folderURL = paths.outputs.appending(path: name, directoryHint: .isDirectory)
        let seeded = BeatsCache.seed(name, folder: folderURL)
        lines.append(seeded.map { "Beats from the cache: \($0.line) (\($0.attempts) tr\($0.attempts == 1 ? "y" : "ies"), temperature \($0.temperature.map { String($0) } ?? "none"), seed \($0.seed.map(String.init) ?? "none"))" }
                     ?? "No cached beats for this transcript: the make asks Qwen3.8-27B and the time is the make's.")

        // 1. Version 1: Clear, the House Style.
        var started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let record1 = try XCTUnwrap(recording.video, "version 1 was made (\(recording.videoProblem ?? recording.statusReason ?? "no reason"))")
        let folder = try XCTUnwrap(recording.outputFolder)
        precondition(folder.hasPrefix(paths.outputs.path + "/"), "development outputs only")
        if seeded == nil, let data = try? Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard)), let heard = PlanWords.from(json: data),
           let made = BeatsFile.cached(in: folderURL, transcriptSHA256: heard.transcriptSHA256) {
            try? BeatsCache.write(made)
            lines.append("Beats made in the make: \(made.line)")
        }
        let plan = try XCTUnwrap(EditPlan.read(folder: folder))
        let words = try XCTUnwrap(PlanWords.from(json: Data(contentsOf: folderURL.appending(path: TranscriptFiles.asHeard))))
        let timeline = EditTimeline(plan: plan)
        let mp4 = folderURL.appending(path: VideoStep.folderName).appending(path: record1.fileName)
        lines.append("")
        lines.append(String(format: "13 Sep, Clear (version 1): made in development in %.0f s, %d model request(s); %@", Date().timeIntervalSince(started), requests(), plan.summary))
        for line in plan.planLines ?? [] { lines.append("  Plan: " + line) }
        lines.append("  \(plan.pictureSummary ?? "no picture line")")
        lines.append("  Ready checklist: \(record1.summary)" + (record1.failed > 0 ? ": " + record1.checklist.filter { $0.status == .fail }.map(\.text).joined(separator: "; ") : ""))
        verdict("Every PlanValidation rule holds on the made plan", PlanValidation.check(plan, words: words).isEmpty,
                PlanValidation.check(plan, words: words).map(\.line).joined(separator: "; "))

        // 2. Check 3, Clear in full.
        let count = VisualPlan.count(plan)
        verdict("check 3 (Clear): 6 to 8 visual changes a minute, every change counted (cuts, changes of framing, texts coming in)", (6...8).contains(count.perMinute),
                String(format: "%d changes in %.2f min, %.2f a minute (%d cuts and changes of framing, %d texts coming in)", count.changes, count.minutes, count.perMinute,
                       count.pictureChanges, count.textIns))
        verdict("check 3 (Clear): 10 or more visual changes in the first 30 s", count.changesFirst30 >= 10, "\(count.changesFirst30)")
        verdict("check 3 (Clear): every punch-in at most 1.15 (1080p source)", count.largestScale <= 1.15 + 1e-9 && count.punchIns > 0,
                String(format: "largest %.3f of %d punch-ins and %d push-ins", count.largestScale, count.punchIns, count.pushIns))
        let texts = plan.visual.filter(\.isText)
        var textLines: [String] = []
        var spoken = 0, spokenSame = 0
        for item in texts {
            let at = timeline.editFrame(span: item.span, original: item.in ?? -1).map { Format.timecode(timeline.seconds($0)) } ?? "?"
            let shown = (item.lines ?? []).joined(separator: " ")
            switch item.kind {
            case EditPlan.Visual.keyPhrase, EditPlan.Visual.term:
                spoken += 1
                guard let ids = item.words, ids.count == 2, let a = PlanWord.index(of: ids[0]), let b = PlanWord.index(of: ids[1]) else { continue }
                let said = PlanWords.text(words.words[a...b])
                if PlanValidation.sameWords(shown, said) { spokenSame += 1 }
                textLines.append("\(item.kind) at \(at) of the video: \u{201C}\(shown)\u{201D}; said at \(Format.timecode(words.words[a].start)): \u{201C}\(said)\u{201D}")
            default:
                textLines.append("\(item.kind) at \(at) of the video: \u{201C}\(shown)\u{201D} (Ivan's own words: the title in Info, the name he gave)")
            }
        }
        var hookSame = true
        for span in plan.hookSpans {
            guard let a = PlanWord.index(of: span.from), let b = PlanWord.index(of: span.to) else { hookSame = false; continue }
            if PlanWords.comparable(span.text) != PlanWords.comparable(PlanWords.text(words.words[a...b])) { hookSame = false }
        }
        let hookText = plan.hookSpans.map(\.text).joined(separator: " ")
        verdict("check 3 (Clear): every on-screen text equals the transcript's words for its range (case and spacing aside)", spoken > 0 && spoken == spokenSame && hookSame,
                "\(spokenSame) of \(spoken) key phrases and terms; the opening line's \(plan.hookSpans.count) span(s) \(hookSame ? "word for word" : "NOT word for word"); "
                + "\(texts.count - spoken) texts in Ivan's own words")
        for line in textLines { lines.append("  " + line) }
        if let hook = plan.hook, let first = plan.words.first(where: { $0.id == hook.from }) {
            verdict("The opening line: the talk's own words, 5 to 15 s, played first, then the title", (5...15).contains(hook.seconds)
                    && texts.first { $0.kind == EditPlan.Visual.title }.flatMap { timeline.editFrame(span: $0.span, original: $0.in ?? -1) } == timeline.hookFrames,
                    String(format: "%.2f s from %@ of the recording: \u{201C}%@\u{201D}; the title at %@ of the video", hook.seconds, Format.timecode(first.in), hookText,
                           Format.timecode(timeline.seconds(timeline.hookFrames))))
        } else {
            verdict("The opening line: the talk's own words, 5 to 15 s, played first, then the title", false, "no opening line was chosen")
        }
        let chapterTimes = plan.chapters.compactMap(\.seconds)
        verdict("Chapters: three or more, the first at 0:00, each at least 10 s, in Description.txt", plan.chapters.count >= 3 && chapterTimes.first == 0
                && zip(chapterTimes, chapterTimes.dropFirst()).allSatisfy { $1 - $0 >= 10 } && record1.checklist.contains { $0.item == "Chapters" && $0.status == .pass },
                plan.chapters.map { "\(VideoDescription.stamp($0.seconds ?? 0)) \($0.title)" }.joined(separator: "; "))
        if let held = plan.held {
            let fs = plan.frameDuration.seconds
            let over = VisualPlan.shots(plan, timeline: timeline).filter { s in
                let x = Double(s.sourceFrame) * fs, y = x + Double(s.frames) * fs
                return y > held.start + 0.5 && x < held.end - 0.5
            }
            let cutInside = plan.removed.filter { $0.from < held.end && $0.to > held.start }
            verdict("The held moment: 30 to 60 s of the main point, one still shot, nothing cut inside", (30...60).contains(held.end - held.start)
                    && over.count == 1 && over.first?.scale == 1 && cutInside.isEmpty,
                    String(format: "%.1f s from %@; %d shot(s) over it at scale %@; %d cuts inside", held.end - held.start, Format.timecode(held.start), over.count,
                           over.map { String(format: "%.2f", $0.scale) }.joined(separator: ", "), cutInside.count))
        } else {
            verdict("The held moment: 30 to 60 s of the main point, one still shot, nothing cut inside", false, "no held moment was chosen")
        }
        verdict("Speech ends 5 s before the last frame (within a frame)", abs(count.afterLastWord - 5) <= plan.frameDuration.seconds + 1e-6,
                String(format: "%.3f s", count.afterLastWord))
        verdict("The file is the opening line, the kept spans and the held ending", abs(record1.duration - timeline.duration) <= plan.frameDuration.seconds + 0.0005,
                String(format: "MP4 %.3f s, plan %.3f s (opening line %.2f s)", record1.duration, timeline.duration, plan.hook?.seconds ?? 0))

        // 3. Check 4 at every text moment.
        let plain = try await CompositionBuilder.build(plan: plan, original: talk, drawText: false)
        let made = AVURLAsset(url: mp4)
        var allMeasured = 0, allInside = 0, allClear = 0, allMoments = 0, faceCount = 0
        var nearest = Double.infinity
        var perText: [String] = []
        for (n, item) in texts.enumerated() {
            guard let start = timeline.editFrame(span: item.span, original: item.in ?? -1), let box = item.box else { continue }
            let frames = Int64(((item.seconds ?? 0) / timeline.frame.seconds).rounded())
            let planned = CGRect(x: box[0], y: box[1], width: box[2], height: box[3])
            // From the moment every word of a key phrase is in, every 0.5 s, and its last frames.
            let settle = item.kind == EditPlan.Visual.keyPhrase ? Int64(((OverlayKind.wordStagger * Double(max(0, (item.lines?.first?.split(separator: " ").count ?? 1) - 1)) + 0.3)
                                                                         / timeline.frame.seconds).rounded()) : 3
            let step = Int64((0.5 / timeline.frame.seconds).rounded())
            var moments = Array(stride(from: start + settle, to: start + frames - 2, by: Int(step)))
            moments.append(start + frames - 3)
            var inside = 0, clear = 0, measured = 0
            var union: CGRect?
            var brightness: [Double] = []
            for frame in moments {
                let at = timeline.time(frame)
                let image = try await StyleTests.image(made, at: at)
                let without = try await RenderTests.frame(plain.composition, videoComposition: plain.videoComposition, at: at)
                guard let ink = Self.markBox(StyleTests.picture(image), without, near: planned) else { continue }
                brightness.append(Self.brightness(without, in: planned))
                measured += 1
                union = union.map { $0.union(ink) } ?? ink
                if OverlayLayout.titleSafe.contains(ink) { inside += 1 }
                let found = try await DetectFaceRectanglesRequest().perform(on: image)
                let boxes = found.map { $0.boundingBox.toImageCoordinates(CGSize(width: 1, height: 1), origin: .upperLeft) }
                faceCount += boxes.count
                if !boxes.contains(where: { $0.intersects(ink) || $0.intersects(planned) }) { clear += 1 }
                for b in boxes { nearest = min(nearest, TextAcceptanceTests.gap(b, ink)) }
                if frame == moments[moments.count / 2] {
                    try StyleTests.writePNG(image, to: forIvan.appending(path: String(format: "m9d-13-Sep-%02d-%@-%@.png", n + 1, item.kind,
                                                                                         Format.timecode(timeline.seconds(frame)).replacingOccurrences(of: ":", with: "-"))))
                }
            }
            allMoments += moments.count
            allMeasured += measured
            allInside += inside
            allClear += clear
            perText.append(String(format: "%@ at %@: %d of %d frames drawn, %d inside title safe, %d clear of faces; pixels x %.3f to %.3f, y %.3f to %.3f; the picture under it %.0f of 255 bright",
                                  item.kind, Format.timecode(timeline.seconds(start)), measured, moments.count, inside, clear, union?.minX ?? -1, union?.maxX ?? -1,
                                  union?.minY ?? -1, union?.maxY ?? -1, brightness.isEmpty ? -1 : brightness.reduce(0, +) / Double(brightness.count)))
        }
        verdict("check 4: every text is drawn at every moment measured", allMeasured == allMoments && allMoments > 0,
                "\(allMeasured) of \(allMoments) frames, every 0.5 s of \(texts.count) texts")
        verdict("check 4: every text box inside the frame's title-safe area", allInside == allMeasured && allMeasured > 0, "\(allInside) of \(allMeasured)")
        verdict("check 4: no text intersects a face box (Vision, on the made frame)", allClear == allMeasured && allMeasured > 0,
                String(format: "%d of %d frames clear; %d faces found in them; the nearest %.3f of the frame away", allClear, allMeasured, faceCount, nearest.isFinite ? nearest : -1))
        for line in perText { lines.append("  " + line) }

        // 4. Check 6: version 2 with a direction, Play switches the Viewer, Approve names version 2.
        model.setDirection(RecordingDirection(prompt: "More energetic. Faster, more frequent cuts."), for: recording)
        started = Date()
        await model.runner.process(recording, trigger: .byHand)
        let record2 = try XCTUnwrap(recording.video, "version 2 was made (\(recording.videoProblem ?? recording.statusReason ?? "no reason"))")
        let versions = recording.versions
        lines.append("")
        lines.append(String(format: "Version 2 made in %.0f s: %@", Date().timeIntervalSince(started), versions.version(2)?.line ?? "none"))
        verdict("check 6: two versions exist, version 2 in use", versions.versions.map(\.number) == [1, 2] && versions.current == 2,
                versions.versions.map(\.line).joined(separator: " | "))
        model.open(recording)
        func playing(_ number: Int) async throws -> (seconds: Double, planMadeAt: Date?) {
            model.playVersion(number, of: recording)
            model.openViewer(recording)
            model.viewer.choose(.video, recording: recording)
            let ready = await model.viewer.videoItemReady(timeout: .seconds(180))
            let item = try XCTUnwrap(ready, model.viewer.videoNote ?? "the Video did not load")
            let seconds = try await item.asset.load(.duration).seconds
            return (seconds, model.viewer.videoPlan?.madeAt)
        }
        let v1 = try await playing(1), v2 = try await playing(2), back = try await playing(1)
        let plan1At = versions.version(1)?.video.planMadeAt, plan2At = versions.version(2)?.video.planMadeAt
        func same(_ a: Date?, _ b: Date?) -> Bool { a != nil && b != nil && abs(a!.timeIntervalSince(b!)) < 1 }
        verdict("check 6: Play switches the Viewer between the versions (each plays its own plan and length)",
                same(v1.planMadeAt, plan1At) && same(v2.planMadeAt, plan2At) && same(back.planMadeAt, plan1At)
                    && abs(v1.seconds - record1.duration) < 0.1 && abs(v2.seconds - record2.duration) < 0.1,
                String(format: "Play 1: %.2f s (made %.2f s); Play 2: %.2f s (made %.2f s); Play 1 again: %.2f s; plans %@ / %@", v1.seconds, record1.duration, v2.seconds,
                       record2.duration, back.seconds, same(v1.planMadeAt, plan1At) ? "version 1's" : "WRONG", same(v2.planMadeAt, plan2At) ? "version 2's" : "WRONG"))
        model.playVersion(2, of: recording)
        let question = model.approvalVersionLine(recording) ?? ""
        let approved = model.approve(recording)
        let receiptURL = model.approvedFolder(for: recording).appending(path: Approval.receiptName)
        precondition(receiptURL.path.hasPrefix(paths.approved.path + "/"), "development Approved only")
        let receipt = (try? String(contentsOf: receiptURL, encoding: .utf8)) ?? ""
        verdict("check 6: Approve names version 2 (its question and its receipt)", approved && question.hasPrefix("Version 2, made ")
                && receipt.contains("## Video version\n\nVersion 2, made "),
                "\(approved ? "approved into \(paths.display(model.approvedFolder(for: recording).path))" : "NOT approved: \(recording.statusReason ?? "")"); question: \u{201C}\(question)\u{201D}")

        verdict("Nothing went to a cloud provider", cloudCalls.count == 0, "\(cloudCalls.count) cloud calls; planning on LM Studio")
        verdict("The original is unchanged (size and modification date)", fingerprint(talk) == before, fingerprint(talk))
        let text = (["v2 part M9d acceptance (hook, chapters, versions), \(Date().formatted(date: .abbreviated, time: .standard))"] + lines
                    + ["", failures == 0 ? "Every check passed." : "\(failures) check(s) failed.",
                       "Frames written for Ivan (measured, not looked at by the build, D1): \(forIvan.path)"]).joined(separator: "\n") + "\n"
        try text.write(to: out.appending(path: "acceptance-hook.txt"), atomically: true, encoding: .utf8)
        print(text)
        model.log.write("Acceptance test for v2 part M9d finished.")
    }

    /// Where a text changed the frame: the pixels around its planned box (the box widened by its shadow, slide and rise) whose
    /// brightness moved by 40 or more either way against the same frame drawn without text, when there are 30 or more. The type
    /// raises it; its shadow lowers it, which is what shows over a bright wall, where white type alone barely moves it (measured
    /// 15 Oct: TextTests' rise-only measure found no "Asana" over the 13 Sep floor). Looked for near the box only, because the
    /// encoder moves a moving teacher's pixels by 40 too (the whole frame searched found "changes" over a face at 14:08).
    static func markBox(_ with: RenderTests.Picture, _ without: RenderTests.Picture, near box: CGRect) -> CGRect? {
        let w = Double(with.width), h = Double(with.height)
        let room = box.insetBy(dx: -(OverlayLayout.shadowRoom + 24) / 1920, dy: -(OverlayLayout.shadowRoom + 16) / 1080)
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1, count = 0
        for y in max(0, Int(room.minY * h))..<min(with.height, Int(room.maxY * h) + 1) {
            for x in max(0, Int(room.minX * w))..<min(with.width, Int(room.maxX * w) + 1) {
                let i = (y * with.width + x) * 4
                let a = (Int(with.rgba[i]) + Int(with.rgba[i + 1]) + Int(with.rgba[i + 2])) / 3
                let b = (Int(without.rgba[i]) + Int(without.rgba[i + 1]) + Int(without.rgba[i + 2])) / 3
                if abs(a - b) >= 40 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y); count += 1 }
            }
        }
        guard count >= 30 else { return nil }
        return CGRect(x: Double(minX) / w, y: Double(minY) / h, width: Double(maxX - minX + 1) / w, height: Double(maxY - minY + 1) / h)
    }

    /// The mean brightness (0 to 255) of a picture inside a box given in fractions from the top left.
    static func brightness(_ p: RenderTests.Picture, in box: CGRect) -> Double {
        var sum = 0.0, n = 0
        for y in Int(box.minY * Double(p.height))..<min(p.height, Int(box.maxY * Double(p.height))) {
            for x in Int(box.minX * Double(p.width))..<min(p.width, Int(box.maxX * Double(p.width))) {
                let i = (y * p.width + x) * 4
                sum += Double(Int(p.rgba[i]) + Int(p.rgba[i + 1]) + Int(p.rgba[i + 2])) / 3
                n += 1
            }
        }
        return n == 0 ? 0 : sum / Double(n)
    }

    private func fingerprint(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return "\(values?.fileSize ?? -1) \(values?.contentModificationDate?.timeIntervalSince1970 ?? -1)"
    }
}
