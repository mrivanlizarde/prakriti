import Foundation
import SwiftData

/// Realistic sample data for snapshots, previews and tests. The three studio recordings and their
/// numbers are real (engine v0 measured them on 8 Oct: the 13 Sep talk at -16.8 LUFS, peak -1.6
/// dBFS, 2,948 words reaching 15:47 of 15:48; the 14 Sep class silent, loudest point -91 dB).
/// The three short clips are the kind of test files milestones 2 and 3 cut from the 13 Sep talk.
/// Fixtures only ever go into an in-memory store.
@MainActor
enum Fixtures {
    /// Sat 10 Oct 2026, 11:50 am, the moment every fixture screen is drawn at.
    static var now: Date { date(2026, 10, 10, 11, 50) }

    static func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s)) ?? .distantPast
    }

    static func populate(_ context: ModelContext, paths: AppPaths) {
        // Default outputs.
        var defaults: [OutputKind: OutputSetting] = [:]
        for kind in OutputKind.allCases {
            let setting = OutputSetting(kind: kind)
            context.insert(setting)
            defaults[kind] = setting
        }

        // Sources.
        let studio = Source(name: "Studio Recordings", path: paths.studioRecordings.path, kind: .folder, mode: .automatic,
                            addedAt: date(2026, 10, 8, 16, 0))
        let drop = Source(name: "Drop folder", path: paths.root.appending(path: "Drop").path, kind: .dropFolder, mode: .askFirst,
                          addedAt: date(2026, 10, 8, 16, 1))
        context.insert(studio)
        context.insert(drop)
        for source in [studio, drop] {
            for kind in OutputKind.allCases {
                let setting = defaults[kind]?.copy() ?? OutputSetting(kind: kind)
                if source === studio, kind == .titlesNotesChapters { setting.isOn = true }
                context.insert(setting)
                setting.source = source
            }
        }

        let studioFolder = paths.studioRecordings.path
        let outputs = paths.root.appending(path: "Outputs").path

        // Sun 13 Sep: the talk, ready for Ivan's yes.
        let talk13 = Recording(filePath: studioFolder + "/2026-09-13/2026-09-13 18-25-44.mp4", title: "Talk with Gabriel",
                               recordedAt: date(2026, 9, 13, 18, 25, 44), foundAt: date(2026, 10, 9, 16, 15),
                               duration: 947.78, sizeBytes: 730_464_600, status: .readyForYourYes, kind: .talk)
        talk13.statusReason = "Episode audio and transcript are ready. Speakers are not checked yet."
        talk13.loudestDB = -3.4
        talk13.averageDB = -30
        talk13.inputLUFS = -26.67
        talk13.coverageOK = true
        talk13.loudnessLUFS = -16.8
        talk13.truePeakDBFS = -1.6
        talk13.transcriptReaches = 947
        talk13.wordCount = 2948
        talk13.outputFolder = outputs + "/2026-09-13 18-25-44"
        context.insert(talk13)
        talk13.source = studio
        addRun(context, to: talk13, start: date(2026, 10, 9, 16, 15, 11), trigger: .fileEvent, outcome: .ready,
               summary: "Ready for your yes.", steps: [
                RunStep(name: "Checked the file is complete", state: .done, seconds: 60, detail: "Opens, its size held steady, and its last seconds play."),
                RunStep(name: "Sound check", state: .done, seconds: 1, detail: "Loudest point -3.4 dB."),
                RunStep(name: "Transcript", state: .done, seconds: 21, detail: "2,948 words."),
                RunStep(name: "Coverage check", state: .done, seconds: 1, detail: "Reaches 15:47 of 15:48."),
                RunStep(name: "Episode audio", state: .done, seconds: 13, detail: "-16.8 LUFS, peak -1.6 dBFS."),
                RunStep(name: "Report", state: .done, seconds: 1, detail: nil),
               ])

        // Mon 14 Sep: the class recorded without sound. Refused, nothing made.
        let class14 = Recording(filePath: studioFolder + "/2026-09-14/2026-09-14 20-00-09.mp4", title: "Class",
                                recordedAt: date(2026, 9, 14, 20, 0, 9), foundAt: date(2026, 10, 9, 21, 4),
                                duration: 3702.27, sizeBytes: 2_858_813_029, status: .needsADecision, kind: .lesson)
        class14.statusReason = "No usable sound: the loudest point is -91 dB. Nothing was made from it."
        class14.loudestDB = -91
        class14.averageDB = -91
        context.insert(class14)
        class14.source = studio
        addRun(context, to: class14, start: date(2026, 10, 9, 21, 4), trigger: .fileEvent, outcome: .needsADecision,
               summary: "No usable sound.", steps: [
                RunStep(name: "Checked the file is complete", state: .done, seconds: 60, detail: "Opens, its size held steady, and its last seconds play."),
                RunStep(name: "Sound check", state: .failed, seconds: 2, detail: "Loudest point -91 dB. Stopped here."),
                RunStep(name: "Transcript", state: .skipped, seconds: nil, detail: nil),
                RunStep(name: "Episode audio", state: .skipped, seconds: nil, detail: nil),
               ])

        // Sun 6 Sep: the episode 1 talk, being worked on now.
        let talk6 = Recording(filePath: studioFolder + "/2026-09-06/2026-09-06 18-06-33.mp4", title: "Talk with Gabriel",
                              recordedAt: date(2026, 9, 6, 18, 6, 33), foundAt: date(2026, 10, 10, 11, 46),
                              duration: 3339.10, sizeBytes: 2_578_079_009, status: .working, kind: .talk)
        talk6.currentStep = "Making the episode audio"
        context.insert(talk6)
        talk6.source = studio
        addRun(context, to: talk6, start: date(2026, 10, 10, 11, 46), trigger: .makeAgain, outcome: .running,
               summary: "", steps: [
                RunStep(name: "Checked the file is complete", state: .done, seconds: 60, detail: "Opens, its size held steady, and its last seconds play."),
                RunStep(name: "Sound check", state: .done, seconds: 2, detail: nil),
                RunStep(name: "Transcript", state: .done, seconds: 78, detail: nil),
                RunStep(name: "Coverage check", state: .done, seconds: 1, detail: "Reaches 55:38 of 55:39."),
                RunStep(name: "Episode audio", state: .running, seconds: nil, detail: nil),
                RunStep(name: "Report", state: .waiting, seconds: nil, detail: nil),
               ])

        // Test clips in the drop folder.
        let dropFolder = drop.path
        let clip90 = Recording(filePath: dropFolder + "/2026-09-13 clip 90s.mp4", recordedAt: date(2026, 9, 13, 18, 25, 44),
                               foundAt: date(2026, 10, 10, 11, 48), duration: 90, sizeBytes: 69_400_000, status: .found)
        context.insert(clip90)
        clip90.source = drop

        let clip45 = Recording(filePath: dropFolder + "/2026-09-13 clip 45s.mp4", recordedAt: date(2026, 9, 13, 18, 25, 44),
                               foundAt: date(2026, 10, 10, 10, 31), duration: 45, sizeBytes: 34_700_000, status: .skipped, kind: .test)
        clip45.statusReason = "Under 60 seconds, so it was filed as a test. No notice was sent."
        context.insert(clip45)
        clip45.source = drop

        let clipBroken = Recording(filePath: dropFolder + "/2026-09-13 clip broken.mp4", recordedAt: date(2026, 9, 13, 18, 25, 44),
                                   foundAt: date(2026, 10, 10, 10, 12), duration: 120, sizeBytes: 52_100_000, status: .couldntFinish)
        clipBroken.statusReason = "The last seconds of the file do not play. Tried three times. The original is untouched."
        context.insert(clipBroken)
        clipBroken.source = drop

        // Activity.
        let lines: [(Date, LogLevel, String)] = [
            (date(2026, 10, 10, 11, 48), .info, "Found 2026-09-13 clip 90s.mp4 in Drop folder. Work starts once it finishes copying."),
            (date(2026, 10, 10, 11, 46), .info, "Started Sun 6 Sep again with new settings."),
            (date(2026, 10, 10, 11, 41), .info, "Checked 2 folders. Nothing new."),
            (date(2026, 10, 10, 10, 40), .problem, "Couldn't finish 2026-09-13 clip broken.mp4 after three tries. The original is untouched."),
            (date(2026, 10, 10, 10, 31), .info, "Filed 2026-09-13 clip 45s.mp4 as a test (45 s). No notice sent."),
            (date(2026, 10, 10, 10, 1), .info, "Checked 2 folders. Nothing new."),
            (date(2026, 10, 9, 21, 6), .attention, "Mon 14 Sep has no usable sound (loudest point -91 dB). Needs a decision. Nothing was made."),
            (date(2026, 10, 9, 16, 17), .info, "Sun 13 Sep is ready for your yes: -16.8 LUFS, peak -1.6 dBFS, transcript reaches 15:47 of 15:48."),
            (date(2026, 10, 9, 16, 15), .info, "Found Sun 13 Sep in Studio Recordings (15 min 48 s)."),
        ]
        for (at, level, message) in lines {
            context.insert(LogEntry(at: at, level: level, message: message))
        }
        try? context.save()
    }

    private static func addRun(_ context: ModelContext, to recording: Recording, start: Date, trigger: RunTrigger,
                               outcome: RunOutcome, summary: String, steps: [RunStep]) {
        let run = Run(startedAt: start, trigger: trigger, outcome: outcome, summary: summary, steps: steps)
        let total = steps.compactMap(\.seconds).reduce(0, +)
        if outcome != .running { run.endedAt = start.addingTimeInterval(total) }
        context.insert(run)
        run.recording = recording
    }

    /// A model filled with fixtures, in memory only, for snapshots, previews and the real-window
    /// capture. Snapshots draw it as the live app will look (`.live`); the real-window capture runs
    /// it in this build's own mode, so the development refusals still apply.
    static func model(empty: Bool = false, mode: AppMode = .live, log: AppLog = AppLog(directory: nil)) -> AppModel {
        let paths = AppPaths(mode: mode)
        let model = AppModel(container: AppModel.inMemoryContainer(), paths: paths, settings: .ephemeral(),
                             log: log, now: { Fixtures.now })
        if empty {
            for kind in OutputKind.allCases { model.context.insert(OutputSetting(kind: kind)) }
            try? model.context.save()
        } else {
            populate(model.context, paths: paths)
        }
        model.isWatching = true
        model.watcher.isRunning = true
        model.watcher.lastCheck = Fixtures.now.addingTimeInterval(-120)
        for source in (try? model.context.fetch(FetchDescriptor<Source>())) ?? [] {
            model.watcher.states[source.id] = SourceWatchState(health: .ok, checkedAt: Fixtures.now.addingTimeInterval(-120),
                                                               fileCount: source.recordings.count)
        }
        model.notifier.permission = .allowed
        model.loginItem = .on
        return model
    }

    /// The state right after the switch-over, before Ivan has answered macOS's prompt for the
    /// Documents folder: the studio folder cannot be read yet.
    static func waitingForPermission(_ model: AppModel) {
        for source in (try? model.context.fetch(FetchDescriptor<Source>())) ?? [] where source.kind == .folder {
            model.watcher.states[source.id] = SourceWatchState(health: .waitingForPermission, checkedAt: Fixtures.now.addingTimeInterval(-120))
        }
        model.notifier.permission = .waitingForAnswer
    }
}
