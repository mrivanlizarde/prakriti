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

    /// The podcast-ready episode of the 13 Sep talk as the acceptances measured it (10 Oct, 11:46 pm, and
    /// 11 Oct, 2:21 am: -16.03 LUFS, true peak -1.78 dBTP, range 3.7 LU, 946.55 s), run through the real
    /// checklist builder with nothing set on the Outputs screen: show name and artwork MISSING.
    static func podcastReady13(_ talk: Recording) -> PodcastReadyRecord {
        let facts = PodcastEpisodeFacts(title: talk.title, notes: talk.notes, recordedAt: talk.recordedAt, label: "Sun 13 Sep", kind: .talk, fileName: talk.fileName)
        let tag = ID3.Tag(version: 4, text: ["TIT2": talk.title, "TDRC": "2026", "TCON": "Podcast"], comment: "A talk.",
                          frameIDs: ["TIT2", "TDRC", "TCON", "COMM", "CTOC", "CHAP", "CHAP", "CHAP"])
        let measured = PodcastPackage.Measured(lufs: -16.03, truePeak: -1.78, lra: 3.7, normalizationType: "linear", sampleRate: 44_100, bitrateKbps: 96,
                                               channels: 1, duration: 946.55, expectedDuration: 946.55, bytes: 11_361_543, tailDecodes: true, tag: tag,
                                               intended: ["TIT2", "TCON", "TDRC", "COMM", "CTOC"], artwork: nil, chapterProblem: nil, chaptersWritten: 3,
                                               captions: (137, 0.08, 946.4), captionsProblem: nil)
        let written = WrittenPackage.decode(talk.writtenJSON)
        return PodcastReadyRecord(fileName: talk.title + ".mp3", integratedLUFS: -16.03, truePeak: -1.78, loudnessRange: 3.7, normalizationType: "linear",
                                  sampleRate: 44_100, bitrateKbps: 96, channels: 1, duration: 946.55, expectedDuration: 946.55, bytes: 11_361_543,
                                  talkLUFS: -26.67, captions: 137, chapters: 3,
                                  checklist: PodcastPackage.checklist(measured, settings: PodcastReadySettings(), facts: facts, written: written),
                                  madeAt: date(2026, 10, 11, 2, 21),
                                  fingerprint: PodcastPackage.fingerprint(settings: PodcastReadySettings(), facts: facts, written: written),
                                  // The files and sizes the episode text's acceptance left (11 Oct, 2:21 am), named for this title.
                                  files: [.init(name: talk.title + ".mp3", bytes: 11_360_986), .init(name: talk.title + ".srt", bytes: 20_629),
                                          .init(name: talk.title + ".vtt", bytes: 20_197), .init(name: PodcastPackage.markdownName, bytes: 4_370),
                                          .init(name: PodcastPackage.textName, bytes: 4_265), .init(name: PodcastPackage.checklistName, bytes: 3_453)])
    }

    /// The capture check as it measured the 13 Sep talk on Mon 12 Oct (v2 part M4b): 1920 by 1080 at 29.97 fps,
    /// H.264 High, Rec. 709, one stereo AAC track at -26.6 LUFS whose left and right differ by -91 dB (one
    /// microphone copied to both). A clip cut from it with `-c copy` measures the same.
    /// What the face step finds in a talk with one person at a time (v2 part M6a): the shape of the 13 Sep talk's
    /// first 12 minutes as measured on Mon 12 Oct (one face in every frame, one track group), as sample data.
    static func facesOnePerson(at checkedAt: Date, duration: Double = 947.78) -> FacesFound {
        var found = FacesFound(checkedAt: checkedAt, duration: duration)
        found.samples = Int(duration * 2)
        found.samplesWithFaces = found.samples
        found.mostAtOnce = 1
        found.tracks = 3
        found.people = [FacePerson(id: 1, label: "Unnamed 1", onScreen: duration - 0.5, first: 0, last: duration - 0.5, appearances: 3,
                                   keyTime: 312.5, keyBox: FaceBox(x: 0.43, y: 0.27, width: 0.13, height: 0.24))]
        found.seconds = 30.1
        return found
    }

    /// The sample talk's people file (v2 part M6d), made up from `facesOnePerson`: one face near its key box, drifting a
    /// little, two sightings a second, as the People overlay reads it. Boxes and times only; never written to disk.
    static func samplePeopleFile(_ id: UUID, faces: FacesFound, extra: [PeopleFile.Track] = []) -> PeopleFile {
        let key = faces.people.first?.keyBox ?? FaceBox(x: 0.43, y: 0.27, width: 0.13, height: 0.24)
        let boxes = stride(from: 0.0, through: faces.duration, by: 0.5).map { time -> [Double] in
            let drift = sin(time / 7) * 0.03
            return [time, key.x + drift, key.y + drift / 3, key.width, key.height, 0.98].map(PeopleFile.round)
        }
        return PeopleFile(recordingID: id, duration: faces.duration, frameWidth: 1920, frameHeight: 1080,
                          tracks: [PeopleFile.Track(id: 1, person: faces.people.first?.id, start: 0, end: faces.duration, boxes: boxes)] + extra,
                          people: faces.people)
    }

    /// The People overlay's sample (v2 part M6d), for the snapshot `20-viewer-people` and the window capture
    /// `12-viewer-people` alike: the sample talk's made-up face, included, and a made-up second face in the corner set to
    /// Hide Face, so both kinds of box (solid, and dashed with its choice in the label) are drawn over the picture. Boxes
    /// in memory only; nothing is written, and no picture of anyone is involved.
    static func showPeopleOverlay(_ model: AppModel, on recording: Recording) {
        guard let faces = recording.faces else { return }
        let corner = (0...1900).map { [Double($0) * 0.5, 0.8, 0.66, 0.06, 0.11, 0.9] }
        model.peopleBoxes.seed(recording, file: samplePeopleFile(recording.id, faces: faces,
                                                                 extra: [PeopleFile.Track(id: 2, person: 2, start: 0, end: 950, boxes: corner)]))
        var choices = recording.choices
        choices.set(.hideFace, for: .face(2))
        recording.choices = choices
        model.viewer.showsPeople = true
    }

    /// The two-people-mixed fixture's answer (v2 part M6a): a second face in the corner from 0:20 to 0:60.
    static func facesTwoPeople(at checkedAt: Date, duration: Double = 90.1) -> FacesFound {
        var found = FacesFound(checkedAt: checkedAt, duration: duration)
        found.samples = 181
        found.samplesWithFaces = 181
        found.mostAtOnce = 2
        found.samplesWithOthers = 80
        found.firstWithOthers = 20.02
        found.tracks = 2
        found.people = [
            FacePerson(id: 1, label: "Unnamed 1", onScreen: 90.1, first: 0, last: 90.1, appearances: 1,
                       keyTime: 41.5, keyBox: FaceBox(x: 0.42, y: 0.27, width: 0.13, height: 0.24)),
            FacePerson(id: 2, label: "Unnamed 2", onScreen: 40, first: 20.02, last: 59.53, appearances: 1,
                       keyTime: 30.5, keyBox: FaceBox(x: 0.81, y: 0.72, width: 0.04, height: 0.07)),
        ]
        found.seconds = 4.9
        return found
    }

    /// One teacher speaking, linked to the one face (v2 part M6b): the 13 Sep talk's shape, made up.
    static func voicesOneTeacher(at checkedAt: Date, duration: Double = 947.78) -> VoicesFound {
        var found = VoicesFound(checkedAt: checkedAt, duration: duration, source: .diarizer)
        found.voices = [FoundVoice(id: 1, label: "Voice 1", speaking: 871, first: 2.1, last: 946.2, track: nil, face: 1, linkedBy: SpeakerLink.byOnlyFace)]
        found.speech = 871
        found.seconds = 9.4
        return found
    }

    /// The two-people-tracks fixture's shape (v2 part M6b): the teacher on track 2, linked to the main face, and a second
    /// voice on track 3 from 0:30 to 0:50 with no face linked.
    static func voicesTwoTracks(at checkedAt: Date, duration: Double = 90.1) -> VoicesFound {
        var found = VoicesFound(checkedAt: checkedAt, duration: duration, source: .tracks)
        found.tracksUsed = [2, 3]
        found.voices = [
            FoundVoice(id: 1, label: "Voice 1", speaking: 78.4, first: 0.3, last: 89.9, track: 2, face: 1, linkedBy: SpeakerLink.byOnlyFace),
            FoundVoice(id: 2, label: "Voice 2", speaking: 19.6, first: 30.1, last: 49.9, track: 3, face: nil, linkedBy: nil),
        ]
        found.speech = 82.0
        found.overlap = 16.0
        found.seconds = 3.2
        return found
    }

    static func capture13(at measuredAt: Date) -> CaptureReport {
        var report = CaptureReport(container: "MP4",
                                   video: .init(codec: "h264", profile: "High", width: 1920, height: 1080, frameRate: 30000.0 / 1001, averageFrameRate: 30000.0 / 1001,
                                                colorSpace: "bt709", colorTransfer: "bt709", colorPrimaries: "bt709", colorRange: "tv"),
                                   audio: [.init(number: 1, codec: "aac", sampleRate: 48000, channels: 2, layout: "stereo", integratedLUFS: -26.6, truePeakDBTP: -3.4,
                                                 loudestDB: -3.4, averageDB: -30, differenceDB: -91)],
                                   duration: 947.78, measuredAt: measuredAt)
        report.findings = CaptureCheck.findings(report)
        return report
    }

    /// A clean recording as the plan designs for (docs/v2/REQUEST.md, "design for clean inputs"): 4K at 30 fps in
    /// a Hybrid MOV, the mix on track 1 and each of two microphones on its own track. Sample data only.
    static func captureClean(at measuredAt: Date) -> CaptureReport {
        var report = CaptureReport(container: "MOV",
                                   video: .init(codec: "hevc", profile: "Main", width: 3840, height: 2160, frameRate: 30, averageFrameRate: 30,
                                                colorSpace: "bt709", colorTransfer: "bt709", colorPrimaries: "bt709", colorRange: "tv"),
                                   audio: [.init(number: 1, codec: "aac", sampleRate: 48000, channels: 2, layout: "stereo", integratedLUFS: -24.1, truePeakDBTP: -4.2,
                                                 loudestDB: -4.4, averageDB: -29, differenceDB: -18.5),
                                           .init(number: 2, codec: "aac", sampleRate: 48000, channels: 1, layout: "mono", integratedLUFS: -25.3, truePeakDBTP: -5.0,
                                                 loudestDB: -5.2, averageDB: -31),
                                           .init(number: 3, codec: "aac", sampleRate: 48000, channels: 1, layout: "mono", integratedLUFS: -27.8, truePeakDBTP: -7.1,
                                                 loudestDB: -7.3, averageDB: -36)],
                                   chapters: 2, duration: 3600, measuredAt: measuredAt)
        report.findings = CaptureCheck.findings(report)
        return report
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
        // What Qwen3.8-27B wrote for this talk in the episode text's acceptance (11 Oct, 2:20 am), as it
        // was checked: every chapter time is a line of the episode's transcript, every quote and pull
        // quote was found word for word, nothing named money, enrollment or an offer. Two of its seven
        // claims are left out here: the speaker's own sales figure and his own early income, so the
        // repository holds no money detail about anyone. Instagram's hashtags are the ones today's check
        // keeps: the model's "Yogalinage" is not a word the teacher says. The transcript names Serenity,
        // so the recording is privacy locked, and the writing that was set to the Claude API stayed here.
        talk13.hasSerenity = true
        var written = WrittenPackage(
            titles: ["A Life Update from Yoga Marga School", "Yoga's Lineage and the School's Next Chapter",
                     "From India to Yin: What Changed at Yoga Marga", "The Two Paths of Yoga Marga Going Forward"],
            showNotes: "The teacher opens by tracing the lineage of modern yoga back to Sri Krishnamacharya, whose disciples including Pattabhi Jois and BKS Iyengar "
                + "carried the practice to the world. He recalls a trip to India to meet Sri BNS Iyengar, who recently turned one hundred, and reflects on how that "
                + "visit prompted a period of rest and reflection for the school.\n\n"
                + "The teacher describes how Yoga Marga is shifting its structure. Serenity will continue leading the coaching program and adding classes to the "
                + "schedule, while the teacher is building a separate track focused on the business side of yoga, drawing on his own experience supporting other "
                + "practitioners. The curriculum for the coming semester will be divided into these two halves.\n\n"
                + "The talk closes with a schedule update. Yin yoga returns to the weekly calendar on Mondays and Wednesdays at 8 p.m. Pacific time, offered as a "
                + "deep body practice for the community. The teacher also walks through the online platform, pointing to the library of recorded classes, "
                + "philosophy teachings, and mentorship content available to students.",
            chapters: [WrittenChapter(start: 0.418458, title: "The Lineage of Yoga"), WrittenChapter(start: 172.218458, title: "Shifting the School's Focus"),
                       WrittenChapter(start: 744.258458, title: "Yin Yoga Returns")],
            checklist: [
                CheckedClaim(claim: "Sri BNS Iyengar celebrated his 100th birthday around the time of the talk.",
                             quote: "one of our gurus, uh, Sri BNS Iyengar, who actually just celebrated his 100th birthday", at: 30.258458),
                CheckedClaim(claim: "Sri BNS Iyengar is described as one of the oldest practitioners and teachers of Ashtanga Yoga.",
                             quote: "he is one of the oldest uh practitioners and teachers of Ashtanga Yoga", at: 44.818458),
                CheckedClaim(claim: "The teacher claims 99.9 percent of yoga practiced today traces back to Sri Krishnamacharya.",
                             quote: "99.9% of every single yoga that is practiced nowadays", at: 56.338458),
                CheckedClaim(claim: "The teacher says the yoga practiced at Yoga Marga dates back to Sri Krishnamacharya at the beginning of the 19th century.",
                             quote: "dates back to these uh these moments with Sri Krishnamacharya at the beginning of the 19th century", at: 96.018458),
                // The teacher's own words keep his contraction, escaped so the rule for Prakriti's own
                // voice (RulesTests, no "we are" contractions in app strings) reads them as quoted data.
                CheckedClaim(claim: "Yin yoga is being added to the weekly schedule on Mondays and Wednesdays at 8 p.m. Pacific time.",
                             quote: "But we\'re doing yin yoga starting Mondays and Wednesdays, starting tomorrow at 8 p.m.", at: 867.218458),
            ],
            tags: ["Ashtanga Yoga", "Yin Yoga", "Yoga of Communication", "Pranayama", "Asana", "Samkhya Philosophy", "Yoga Sutras", "Ahimsa"],
            summary: "The speaker shares an update on the Yoga Marga school, noting a recent trip to India to meet Sri BNS Iyengar, a centenarian Ashtanga Yoga "
                + "practitioner and direct disciple of Sri Krishnamacharya, and reflecting on the lineage that connects the school's teaching back to that tradition. "
                + "The curriculum is being reorganized into two tracks: one led by Serenity focused on coaching, the yoga of communication, and relational practices, "
                + "and another focused on the business and marketing side of running a yoga practice. Weekly yin yoga classes have been added to the schedule, and "
                + "the online platform holds extensive recorded material covering asana, pranayama, anatomy, the sutras, and Samkhya philosophy.",
            writtenBy: "Qwen3.8-27B in LM Studio", writingProvider: ModelProvider.lmStudio.rawValue,
            taggedBy: "Qwen3.8-27B in LM Studio", summarizedBy: "Qwen3.8-27B in LM Studio", lockReason: PrivacyLock.namesTeacher, lockedTasks: ["writing"],
            writtenAt: date(2026, 10, 11, 2, 20, 8), seconds: 1798.4, attempts: 1, writingSeconds: 1457.4,
            promptTokens: 5800, completionTokens: 12445, reasoningTokens: 11218, clock: "episode")
        written.oneLine = "The teacher shares the school's journey through India, the lineage of modern yoga, and how Yoga Marga is reshaping its curriculum and schedule."
        written.keywords = ["Sri Krishnamacharya", "Sri BNS Iyengar", "Ashtanga Yoga lineage", "Yoga Marga School", "yin yoga", "yoga of communication",
                            "coaching program", "business of yoga", "Samkhya philosophy", "Pattabhi Jois"]
        written.social = [
            SocialCaption(platform: .instagram,
                          text: "The teacher traces modern yoga back to Sri Krishnamacharya and shares how that lineage shaped a trip to India. Yoga Marga is splitting "
                            + "its curriculum into two paths, and yin yoga returns to the weekly schedule.",
                          hashtags: ["YinYoga", "YogaMarga", "Krishnamacharya", "AshtangaYoga"],
                          pullQuote: "Yoga is a practice that is more than just asana, pranayama, breathing, stretching.", pullQuoteAt: 527.458458),
            SocialCaption(platform: .linkedin,
                          text: "The teacher reflects on a period of rest that followed a trip to India, and how that pause reshaped the school's direction. Yoga Marga "
                            + "is dividing its curriculum into two tracks: one led by Serenity in coaching and the relational side of yoga, and one the teacher is "
                            + "building around the business of teaching. The talk also covers the lineage of modern yoga through Sri Krishnamacharya and the return "
                            + "of weekly yin yoga to the schedule.",
                          pullQuote: "And if at any point it is becoming a disservice to ourselves, then it impacts our ability to show up for others.", pullQuoteAt: 157.738458),
            SocialCaption(platform: .x,
                          text: "The teacher traces yoga's lineage to Sri Krishnamacharya, shares how a trip to India reshaped the school, and announces yin yoga "
                            + "returning to the weekly schedule.",
                          pullQuote: "Yoga Marga, we\'re not going anywhere, we\'re still here.", pullQuoteAt: 729.618458),
        ]
        talk13.writtenJSON = written.json()
        talk13.podcastReadyJSON = podcastReady13(talk13).json()
        talk13.captureJSON = capture13(at: date(2026, 10, 9, 16, 16, 11)).json()
        talk13.facesJSON = facesOnePerson(at: date(2026, 10, 9, 16, 16, 40)).json()
        context.insert(talk13)
        talk13.source = studio
        addRun(context, to: talk13, start: date(2026, 10, 9, 16, 15, 11), trigger: .fileEvent, outcome: .ready,
               summary: "Waiting for your yes.", steps: [
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
        // The silent class's capture check: its one stereo track measured -91 dB, digital silence.
        var silentCapture = capture13(at: date(2026, 10, 9, 21, 5))
        silentCapture.audio[0] = .init(number: 1, codec: "aac", sampleRate: 48000, channels: 2, layout: "stereo", loudestDB: -91, averageDB: -91, differenceDB: -91)
        silentCapture.duration = 3702.27
        silentCapture.findings = CaptureCheck.findings(silentCapture)
        class14.captureJSON = silentCapture.json()
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
        var clipCapture = capture13(at: date(2026, 10, 10, 10, 31))
        clipCapture.duration = 45
        clip45.captureJSON = clipCapture.json()
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
            (date(2026, 10, 9, 16, 17), .info, "Sun 13 Sep is waiting for your yes: -16.8 LUFS, peak -1.6 dBFS, transcript reaches 15:47 of 15:48."),
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
        // No face of anyone is drawn from sample data: the People tab shows a test pattern in each circle.
        model.faceCrops.useTestPattern = true
        // Nor in a card picture (v2 part M6d): a calm test pattern stands in for each recording whose people were checked,
        // and the Viewer's People overlay draws the sample talk's made-up boxes (`samplePeopleFile`), over a test pattern.
        model.cardPictures.useTestPattern = true
        // Nor in the gallery's key photos (v2 part M7a).
        model.keyPhotos.useTestPattern = true
        for recording in (try? model.context.fetch(FetchDescriptor<Recording>())) ?? [] where recording.title == "Talk with Gabriel" {
            if let faces = recording.faces { model.peopleBoxes.seed(recording, file: samplePeopleFile(recording.id, faces: faces)) }
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
            .openAI: ProviderCheck(state: .notSetUp, line: "No key added. Nothing is sent to OpenAI.", at: tested),
        ]
        // Settings, Models draws the key states set here, never this Mac's Keychain (v2 part M5b).
        model.readsKeysOnAppear = false
        return model
    }

    /// The People gallery as sample data (v2 part M7a): Gabriel named Who Is Teaching on the sample 13 Sep talk (its two-faces
    /// shape: his face and voice, and a corner face nobody named) and on the 6 Sep talk, Name Only and able to appear, so his
    /// key photo is a test pattern; Serenity named in Settings only, not shown in what is published, so she has a monogram
    /// and no recording yet. Nobody has a release, and nothing about a face or a voice is kept.
    static func showGallery(_ model: AppModel) {
        let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
        guard let gabriel = model.addPerson(named: "Gabriel"), let serenity = model.addPerson(named: "Serenity") else { return }
        gabriel.role = .teacher
        serenity.role = .teacher
        serenity.mayAppear = false
        gabriel.pinned = true
        let checked = date(2026, 10, 13, 1, 10)
        if let talk13 = all.first(where: { $0.title == "Talk with Gabriel" && $0.status == .readyForYourYes }) {
            talk13.facesJSON = facesTwoPeople(at: checked, duration: 947.78).json()
            model.applyVoices(voicesTwoTracks(at: checked, duration: 947.78), to: talk13)
            model.setTeacher(gabriel, for: talk13)
        }
        if let talk6 = all.first(where: { $0.title == "Talk with Gabriel" && $0.status != .readyForYourYes }) {
            talk6.facesJSON = facesOnePerson(at: checked, duration: 3339.1).json()
            model.applyVoices(voicesOneTeacher(at: checked, duration: 3339.1), to: talk6)
            model.setTeacher(gabriel, for: talk6)
        }
        try? model.context.save()
    }

    /// A make in progress for the snapshots and the window captures (v2 part M4a): the 6 Sep talk (55:39) on
    /// its episode audio, 40% through that stage, with the 90 s clip waiting in line. Nothing runs: the
    /// progress is drawn from a tracker on the fixed clock, its stages weighted by this Mac's first measured
    /// numbers (`StageTimings.firstGuess`), all treated as measured so the time left shows.
    static func showProgress(_ model: AppModel, paused: Bool = false) {
        let all = (try? model.context.fetch(FetchDescriptor<Recording>())) ?? []
        guard let talk6 = all.first(where: { $0.status == .working }) else { return }
        let clip90 = all.first { $0.fileName == "2026-09-13 clip 90s.mp4" }
        let plan: [PipelineStep] = [.complete, .sound, .speechAudio, .transcript, .coverage, .wordList, .trim, .episode, .loudness, .episodeTranscript, .report]
        let media = talk6.duration ?? 3339.1
        var expected: [PipelineStep: Double] = [:]
        for step in plan { expected[step] = StageTimings().expectedSeconds(step, mediaSeconds: media, stableWait: 60) }
        let started = now.addingTimeInterval(-160)
        var tracker = ProgressTracker(recordingID: talk6.id, label: Format.dayLabel(talk6.sessionDate), plan: plan, expected: expected,
                                      measured: Set(plan), startedAt: started)
        // What the 13 Sep talk's steps took, scaled to 55:39 by the same rates (seconds after the start).
        let taken: [(PipelineStep, Double)] = [(.complete, 61), (.sound, 2.2), (.speechAudio, 1.9), (.transcript, 37.9), (.coverage, 0.0),
                                               (.wordList, 0.0), (.trim, 2.2)]
        var clock = started
        for (step, seconds) in taken {
            tracker.begin(step, at: clock)
            clock = clock.addingTimeInterval(seconds)
            tracker.end(step, state: .done, seconds: seconds, at: clock)
        }
        tracker.begin(.episode, at: clock)
        tracker.report(0.4, at: now)
        tracker.logLine = "Silence at the start and end done in 2.2 s. Trimmed 3.4 s at the start; none at the end."
        if paused { tracker.pause(at: now) }
        let fixed = now
        let job = JobProgress(tracker: tracker, clock: { fixed })
        model.runner.showSample(job: job, waiting: clip90.map { [$0.id] } ?? [])
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
