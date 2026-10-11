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
        // Measured by the milestone 4 acceptance on 10 Oct, with the standard choices.
        talk13.loudestDB = -3.4
        talk13.averageDB = -30
        talk13.inputLUFS = -26.67
        talk13.coverageOK = true
        talk13.loudnessLUFS = -16.8
        talk13.truePeakDBFS = -1.7
        talk13.episodeDuration = 946.6
        talk13.silenceTrimmedStart = 1.18
        talk13.silenceTrimmedEnd = 0
        talk13.transcriptReaches = 947
        talk13.wordCount = 2948
        talk13.wordListFixes = 15
        talk13.outputFolder = outputs + "/2026-09-13 18-25-44"
        // The files engine v0 made for this talk, which are in that folder, so the page's player
        // and transcript show the real talk (read only).
        talk13.madeFiles = ["REPORT.md", "episode.mp3", "transcript.json", "transcript.srt", "transcript.txt", "transcript.vtt"]
        // What Qwen3.8-27B wrote for this talk in milestone 6's acceptance (10 Oct, 7:41 pm), as it
        // was checked: every chapter time is a line of the episode's transcript, every quote was found
        // word for word. Two of its seven claims are left out here: the speaker's own sales figure, so
        // the repository holds no money detail about anyone, and the yin yoga one, whose quote starts
        // with a word the copy rules ban from app strings. The transcript names Serenity, so the
        // recording is privacy locked, and the writing that was set to the Claude API stayed on this Mac.
        talk13.hasSerenity = true
        talk13.writtenJSON = WrittenPackage(
            titles: ["Yoga Marga: Lineage, Sales, and Yin Yoga", "The History and Future of Yoga Marga School",
                     "From Krishnamacharya to the Business of Yoga"],
            showNotes: "The teacher gives a life update on Yoga Marga School, tracing the school's yoga lineage back to Sri Krishnamacharya and Sri BNS Iyengar. "
                + "The talk covers the decision to pause enrollment of new students, the shift in how the two teachers divide their work, and the upcoming "
                + "division of the curriculum into a coaching and mindset track led by Serenity and a business and sales track. The teacher also announces "
                + "the return of weekly yin yoga classes on Mondays and Wednesdays, walks through the online platform, and mentions that new viewers can access a free week.",
            chapters: [WrittenChapter(start: 0.418, title: "Yoga Lineage and Origins"), WrittenChapter(start: 251.938, title: "School Changes Ahead"),
                       WrittenChapter(start: 744.258, title: "Yin Yoga Schedule")],
            checklist: [
                CheckedClaim(claim: "Sri BNS Iyengar recently celebrated his 100th birthday.", quote: "who actually just celebrated his 100th birthday", at: 30.258),
                CheckedClaim(claim: "Sri Krishnamacharya is described as the father of modern yoga.", quote: "he's the father of modern yoga", at: 44.818),
                CheckedClaim(claim: "The teacher states that 99.9% of yoga practiced today traces back to Sri Krishnamacharya.",
                             quote: "99.9% of every single yoga that is practiced nowadays", at: 56.338),
                CheckedClaim(claim: "Pattabhi Jois and BKS Iyengar were named as disciples of Sri Krishnamacharya.",
                             quote: "Pattabhi Jois, BKS Iyengar, some of the other like famous", at: 84.098),
                CheckedClaim(claim: "The teacher is starting a new school group within Yoga Marga focused on sales.",
                             quote: "it's specifically going to be focused on sales", at: 630.858),
            ],
            tags: ["yoga of communication", "coaching program", "business of yoga"],
            summary: "The talk outlines the evolution of the Yoga Marga school following a trip to India and the decision to shift focus away from new student enrollment. "
                + "It details the restructuring of the curriculum into coaching and mindset support alongside a new business-focused program. The session covers "
                + "updates to the online schedule, including the return of weekly yin yoga classes and access to existing educational materials.",
            writtenBy: "Qwen3.8-27B in LM Studio", writingProvider: ModelProvider.lmStudio.rawValue,
            taggedBy: "Apple on-device", summarizedBy: "Apple on-device", lockReason: "Serenity is in this recording", lockedTasks: ["writing"],
            writtenAt: date(2026, 10, 10, 19, 41, 49), seconds: 864.7, attempts: 1, writingSeconds: 846.5,
            promptTokens: 5306, completionTokens: 7710, reasoningTokens: 7117, clock: "episode").json()
        context.insert(talk13)
        talk13.source = studio
        addRun(context, to: talk13, start: date(2026, 10, 9, 16, 15, 11), trigger: .fileEvent, outcome: .ready,
               summary: "Ready for your yes.", steps: [
                RunStep(name: "Checked the file is complete", state: .done, seconds: 60.2, detail: "Opens, its size held steady for 60 s, and its last seconds play."),
                RunStep(name: "Sound check", state: .done, seconds: 0.6, detail: "Loudest point -3.4 dB, average -30 dB."),
                RunStep(name: "Audio for the transcript", state: .done, seconds: 0.5, detail: "Mono, 16 kHz."),
                RunStep(name: "Transcript", state: .done, seconds: 10.5, detail: "2,948 words."),
                RunStep(name: "Coverage check", state: .done, seconds: 0.0, detail: "Reaches 15:47 of 15:48."),
                RunStep(name: "Word list", state: .done, seconds: 0.0,
                        detail: "15 fixes: Iyengar (2), Krishnamacharya (5), Pattabhi Jois (1), Yoga Marga (6), Samkhya (1)."),
                RunStep(name: "Silence at the start and end", state: .done, seconds: 0.6, detail: "Trimmed 1.2 s at the start; none at the end."),
                RunStep(name: "Episode audio", state: .done, seconds: 22.2,
                        detail: "Mono MP3, 128 kbps, from -26.67 LUFS. Loudness leveled moment to moment, not evenly, so it is worth a listen."),
                RunStep(name: "Loudness check", state: .done, seconds: 1.8, detail: "-16.8 LUFS, peak -1.7 dBFS. Plays to its end (15:47)."),
                RunStep(name: "Report", state: .done, seconds: 0.0, detail: "Written to REPORT.md, beside the episode."),
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
        // The Models screen as each provider's test button left it on 10 Oct (milestone 6's acceptance).
        let tested = date(2026, 10, 10, 19, 42)
        model.providerChecks = [
            .lmStudio: ProviderCheck(state: .ok, line: "Answered in 14 s. Loaded Qwen3.8-27B in LM Studio at 65,536 tokens in 8 s. Unloaded again after the test.", at: tested),
            .appleOnDevice: ProviderCheck(state: .ok, line: "Wrote 3 tags in 0.8 s: breath, exhale, pause.", at: tested),
            .ollama: ProviderCheck(state: .notSetUp, line: "Ollama answers. Installed: qwen3:4b. Name one above to use it.", at: tested),
            .claudeAPI: ProviderCheck(state: .notSetUp, line: "No key added. Nothing is sent to Anthropic.", at: tested),
        ]
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
