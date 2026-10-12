import SwiftUI

/// A recording's titles, show notes and chapters (milestone 6): the three title options, each one
/// click from being the recording's title; the show notes, one click from being its notes; the
/// chapters on the episode's clock; the accuracy checklist with each quote found word for word; the
/// tags and summary; who wrote them and, when the privacy lock decided it, why it stayed on this Mac.
struct WritingSection: View {
    @Bindable var recording: Recording
    /// The inspector's Outputs tab leaves the accuracy checklist to the Checks tab, where each claim has
    /// its checkbox (v2 part M3a); v1's recording page shows it here.
    var showsChecklist = true
    @Environment(AppModel.self) private var model

    var body: some View {
        let written = recording.written
        Section {
            if let written {
                Text(byLine(written))
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let lock = lockLine(written) {
                    LockLabel(text: lock)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title options").font(AppFont.headline)
                    ForEach(Array(written.titles.enumerated()), id: \.offset) { _, title in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(title).font(AppFont.body)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 12)
                            if recording.title == title {
                                Text("Its title").font(AppFont.secondary).foregroundStyle(.appSecondary)
                            } else {
                                Button("Use This Title") { model.useTitle(title, for: recording) }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Show notes").font(AppFont.headline)
                        Spacer(minLength: 12)
                        if recording.notes == written.showNotes {
                            Text("Its notes").font(AppFont.secondary).foregroundStyle(.appSecondary)
                        } else {
                            Button("Use as Notes") { model.useNotes(written.showNotes, for: recording) }
                        }
                    }
                    Text(written.showNotes).font(AppFont.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Chapters").font(AppFont.headline)
                    ForEach(Array(written.chapters.enumerated()), id: \.offset) { _, chapter in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(chapter.label).font(AppFont.numbers).foregroundStyle(.appSecondary)
                                .frame(minWidth: 56, alignment: .leading)
                            Text(chapter.title).font(AppFont.body)
                        }
                    }
                }
                .padding(.vertical, 4)
                if let one = written.oneLine, !one.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One-line summary").font(AppFont.headline)
                        Text(one).font(AppFont.body)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
                if let keywords = written.keywords, !keywords.isEmpty {
                    ValueRow(label: "Keywords", value: keywords.joined(separator: ", "))
                }
                if !written.captionTexts.isEmpty {
                    if recording.podcastReady != nil && recording.kind != .lesson {
                        // The captions are words to paste, so they sit with their Copy buttons below.
                        RowNote("Social captions for Instagram, LinkedIn and X and Threads, each with its pull quote, are under Ready to upload, with a Copy button each.")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Social captions").font(AppFont.headline)
                            Text("Drafts to post by hand. Nothing is posted.")
                                .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            ForEach(Array(captionRows(written).enumerated()), id: \.offset) { _, row in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.label).font(AppFont.secondaryEmphasis)
                                    Text(row.text).font(AppFont.body)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let quote = row.quote {
                                        Text(quote).font(AppFont.secondary).foregroundStyle(.appSecondary)
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                if showsChecklist {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accuracy checklist").font(AppFont.headline)
                    Text("Each quote was found word for word in the transcript. Check each claim against the episode before anything is published.")
                        .font(AppFont.secondary).foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(written.checklist.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(item.at.map { WritingText.stamp($0) } ?? "").font(AppFont.numbers).foregroundStyle(.appSecondary)
                                .frame(minWidth: 56, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.claim).font(AppFont.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\u{201C}\(item.quote)\u{201D}").font(AppFont.secondary).foregroundStyle(.appSecondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    ForEach(Array(checkLines(written).enumerated()), id: \.offset) { _, line in
                        Text(line).font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                }
                if !written.tags.isEmpty {
                    ValueRow(label: "Tags", value: written.tags.joined(separator: ", "))
                }
                if let summary = written.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary").font(AppFont.body)
                        Text(summary).font(AppFont.body).foregroundStyle(.appSecondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text(notWrittenLine)
                    .font(AppFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let lock = pendingLockLine {
                    LockLabel(text: lock)
                }
            }
            if let problem = recording.writingProblem {
                Label {
                    Text("Not written on the last try. \(problem)")
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").font(AppFont.body)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                if let busy = busyLine {
                    Text(busy).font(AppFont.secondary).foregroundStyle(.appSecondary)
                }
                Spacer(minLength: 12)
                Button(written == nil ? "Write Titles and Notes" : "Write Again") { model.writeAgain(recording) }
                    .disabled(!model.canWrite(recording))
            }
        } header: {
            SectionHeader("Titles, show notes and chapters")
        }
    }

    private func byLine(_ written: WrittenPackage) -> String {
        var line = "Written by \(written.writtenBy) on \(Format.dayAndTime(written.writtenAt)), in \(Format.length(written.seconds)). "
        line += written.clock == "episode" ? "Times are in the episode." : "Times are in the recording."
        if let tagged = written.taggedBy, tagged != written.writtenBy { line += " Tags by \(tagged)." }
        if let summarized = written.summarizedBy, summarized != written.writtenBy { line += " Summary by \(summarized)." }
        return line
    }

    private func lockLine(_ written: WrittenPackage) -> String? {
        guard let reason = written.lockReason else { return nil }
        if written.lockedTasks.isEmpty { return "Privacy lock: \(reason), so only models on this Mac read it." }
        return "Privacy lock: \(reason), so LM Studio did the \(written.lockedTasks.joined(separator: " and ")) set to the Claude API. Nothing was sent to Anthropic."
    }

    /// Before anything is written: when the lock will change a choice, say so now.
    private var pendingLockLine: String? {
        guard recording.isPrivacyLocked else { return nil }
        let cloud = ModelTask.allCases.filter { !(model.settings.provider[$0] ?? .lmStudio).isLocal }
        guard !cloud.isEmpty else { return nil }
        let reason = Privacy.lockReason(kind: recording.kind, serenity: recording.hasSerenity) ?? "it is privacy locked"
        return "Privacy lock: \(reason), so LM Studio will do the \(cloud.map { $0.title.lowercased() }.joined(separator: " and ")) set to the Claude API."
    }

    /// Each caption with its platform and its pull quote, or the numbered plain captions written before 11 Oct.
    private func captionRows(_ written: WrittenPackage) -> [(label: String, text: String, quote: String?)] {
        if let social = written.social, !social.isEmpty {
            return social.map { caption in
                (caption.platform.title, caption.post,
                 caption.pullQuote.map { "Pull quote" + (caption.pullQuoteAt.map { ", at \(WritingText.stamp($0))" } ?? "") + ": \u{201C}\($0)\u{201D}" })
            }
        }
        return (written.captions ?? []).enumerated().map { ("Caption \($0.offset + 1)", $0.element, nil) }
    }

    private func checkLines(_ written: WrittenPackage) -> [String] {
        var lines: [String] = []
        if !written.leftOutQuotes.isEmpty {
            let n = written.leftOutQuotes.count
            lines.append("\(Format.count(n, "quote")) the model gave \(n == 1 ? "was" : "were") not in the transcript word for word, so \(n == 1 ? "it was" : "they were") left out.")
        }
        if written.leftOutChapters > 0 {
            let n = written.leftOutChapters
            lines.append("\(Format.count(n, "chapter")) did not start at a time in the transcript, so \(n == 1 ? "it was" : "they were") left out.")
        }
        if let left = written.leftOutPullQuotes, !left.isEmpty {
            lines.append("\(Format.count(left.count, "pull quote")) the model gave \(left.count == 1 ? "was" : "were") not one line of the transcript word for word, so \(left.count == 1 ? "it was" : "they were") left out.")
        }
        return lines + written.notes
    }

    private var notWrittenLine: String {
        let on = OutputResolver.isOn(.titlesNotesChapters, recording: recording, source: nil, defaults: model.defaultSettings())
        let writer = model.provider(for: .writing, recording: recording)
        let name = writer == .lmStudio ? Format.modelName(model.settings.lmStudioModel) + " in LM Studio" : writer.title
        return on
            ? "Not written yet. They are written by \(name) with the next Make Again, or now from the transcript with Write Titles and Notes."
            : "Not made for this recording. Write them now from the transcript with \(name), or turn them on under Outputs for this recording."
    }

    private var busyLine: String? {
        if model.runner.isCurrent(recording) { return recording.currentStep.map { $0 + "." } }
        if model.runner.isWaiting(recording) { return "Waiting for its turn." }
        return nil
    }
}

/// The lock symbol and one sentence, as the page's status section shows it.
struct LockLabel: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.fill").font(AppFont.body)
        }
    }
}
