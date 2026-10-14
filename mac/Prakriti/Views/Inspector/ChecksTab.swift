import SwiftData
import SwiftUI

/// The inspector's Checks tab (design spec 3.5.4, as built in part M3a): how the recording was made (the
/// capture check, part M4b), what was measured on the recording and its files (v1's report numbers), the
/// accuracy checklist with a checkbox for each claim, the privacy lock and where each model step ran, and the
/// steps of the last make with their times. The platform checks come with their parts (M8, M11).
struct ChecksTab: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            CaptureSection(recording: recording)
            Section {
                if measured.isEmpty {
                    RowNote(recording.status == .found ? "Nothing is measured until it is made." : "Nothing was measured.")
                }
                ForEach(measured, id: \.label) { row in
                    StackedValue(label: row.label, value: row.value)
                }
            } header: {
                SectionHeader("Measured")
            }
            if let written = recording.written, !written.checklist.isEmpty {
                Section {
                    let done = written.checklist.filter { recording.checkedClaims.contains($0.claim) }.count
                    Text("Each quote was found word for word in the transcript. Tick each claim once you have checked it against the episode: \(done) of \(written.checklist.count) checked.")
                        .font(AppFont.secondary)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(written.checklist.enumerated()), id: \.offset) { _, item in
                        Toggle(isOn: Binding(get: { recording.checkedClaims.contains(item.claim) },
                                             set: { model.setClaim(item.claim, checked: $0, for: recording) })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.claim)
                                    .font(AppFont.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text((item.at.map { WritingText.stamp($0) + ". " } ?? "") + "\u{201C}\(item.quote)\u{201D}")
                                    .font(AppFont.secondary)
                                    .foregroundStyle(.appSecondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                } header: {
                    SectionHeader("Accuracy checklist")
                }
            }
            Section {
                Label {
                    Text(recording.lockLine ?? "Not locked. The models chosen in Settings, Models may read its transcript.")
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: recording.lockLine == nil ? "lock.open" : "lock.fill")
                        .font(AppFont.body)
                }
                if let written = recording.written {
                    ForEach(ranOn(written), id: \.self) { line in
                        Text(line)
                            .font(AppFont.secondary)
                            .foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("The recording itself never leaves this Mac.")
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
            } header: {
                SectionHeader("Privacy")
            }
            if let run = recording.latestRun, !run.steps.isEmpty {
                Section {
                    ForEach(run.steps.filter { $0.state != .skipped }) { step in
                        StepRow(step: step)
                    }
                } header: {
                    SectionHeader("Steps of the last make")
                }
            }
        }
        .formStyle(.grouped)
    }

    /// v1's report numbers, the same words as its recording page.
    private var measured: [(label: String, value: String)] {
        var rows: [(String, String)] = []
        if let loudest = recording.loudestDB {
            rows.append(("Sound in the original", "Loudest point " + Pipeline.db(loudest) + (recording.averageDB.map { ", average " + Pipeline.db($0) } ?? "")))
        }
        if let lufs = recording.loudnessLUFS {
            rows.append(("Episode audio", Format.lufs(lufs) + (recording.truePeakDBFS.map { ", peak " + Format.dbfs($0) } ?? "")))
            if let length = recording.episodeDuration {
                rows.append(("Episode length", Format.timecode(length)
                             + (recording.madeEdits.isEmpty ? Format.trimmed(start: recording.silenceTrimmedStart, end: recording.silenceTrimmedEnd)
                                                            : ", with your trim and cuts")))
            }
        }
        if let words = recording.wordCount {
            let stops = recording.coverageOK == false && recording.transcriptReaches.map { reaches in
                recording.duration.map { $0 - reaches > PipelineOptions().coverageGap } ?? true
            } == true
            let verb = stops ? ", stops at " : ", reaches "
            let reach = recording.transcriptReaches.map { verb + Format.timecode($0) + (recording.duration.map { " of " + Format.timecode($0) } ?? "") } ?? ""
            rows.append(("Transcript", Format.number(words) + " words" + reach))
            if !recording.transcriptGaps.isEmpty {
                rows.append(("Missing words", "No words for " + Format.count(recording.transcriptGaps.count, "stretch", "stretches") + " of speech, at "
                             + TranscriptGaps.list(recording.transcriptGaps) + ". Listen there before trusting the transcript"))
            }
            if let fixes = recording.wordListFixes {
                rows.append(("Word list", fixes == 0 ? "No known mis-hearings found" : Format.count(fixes, "fix", "fixes") + ", listed in the report"))
            }
        }
        return rows
    }

    /// Where each model step ran, from what was written.
    private func ranOn(_ written: WrittenPackage) -> [String] {
        var lines = ["Titles, show notes and chapters: \(written.writtenBy)."]
        if let tagged = written.taggedBy { lines.append("Tags: \(tagged).") }
        if let summarized = written.summarizedBy { lines.append("Summary: \(summarized).") }
        if !written.lockedTasks.isEmpty {
            lines.append("The lock kept the \(written.lockedTasks.joined(separator: " and ")) on this Mac. Nothing was sent off this Mac.")
        }
        return lines
    }
}

/// A label over its value, for a narrow inspector where a value beside its label would wrap.
struct StackedValue: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.secondary)
                .foregroundStyle(.appSecondary)
            Text(value)
                .font(AppFont.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
    }
}

extension Recording {
    /// The privacy lock's line for this recording (design spec C4): the real reason, in words that name no
    /// one (PrivacyLock.decide; since part LOCK only someone set to Leave Out or marked "no release" locks it).
    var lockLine: String? { PrivacyLock.decide(lockSubject).line }
}

extension AppModel {
    /// Ticks or unticks one claim of the accuracy checklist (the Checks tab). Ivan's own review: it changes
    /// no file and no approval. Activity says how many are checked, never the claim's words.
    func setClaim(_ claim: String, checked: Bool, for recording: Recording) {
        if checked {
            guard !recording.checkedClaims.contains(claim) else { return }
            recording.checkedClaims.append(claim)
        } else {
            guard recording.checkedClaims.contains(claim) else { return }
            recording.checkedClaims.removeAll { $0 == claim }
        }
        let checklist = recording.written?.checklist ?? []
        let done = checklist.filter { recording.checkedClaims.contains($0.claim) }.count
        record("\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName)): \(done) of \(checklist.count) accuracy claims checked.")
        try? context.save()
    }
}
