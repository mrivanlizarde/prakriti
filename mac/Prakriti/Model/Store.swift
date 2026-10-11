import Foundation
import SwiftData

enum PrakritiStore {
    static var modelTypes: [any PersistentModel.Type] {
        [Source.self, Recording.self, OutputSetting.self, Run.self, LogEntry.self]
    }

    /// The store at `url`, or an in-memory store when `url` is nil (tests and snapshots).
    static func makeContainer(at url: URL?) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration: ModelConfiguration
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration("Prakriti", schema: schema, url: url)
        } else {
            configuration = ModelConfiguration("Prakriti", schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// First launch: the default output choices, and the folders this mode watches.
    /// Development adds only ~/Prakriti/Dev/Drop. Live (from the switch-over) adds the Studio
    /// Recordings folder and ~/Prakriti/Drop, both making outputs automatically, as engine v0 did.
    /// Each counts as looked at from this moment: engine v0's state.json, read next, is the memory
    /// of what was there before, and anything else that arrives is new.
    @MainActor
    static func seedIfEmpty(_ context: ModelContext, paths: AppPaths, now: Date) throws -> Bool {
        let existing = try context.fetchCount(FetchDescriptor<OutputSetting>())
        guard existing == 0 else { return false }
        for kind in OutputKind.allCases {
            context.insert(OutputSetting(kind: kind))
        }
        var folders: [Source] = []
        if paths.mode == .live {
            folders.append(Source(name: "Studio Recordings", path: paths.studioRecordings.path, kind: .folder, mode: .automatic, addedAt: now))
        }
        folders.append(Source(name: paths.mode == .development ? "Test drop folder" : "Drop folder",
                              path: paths.drop.path, kind: .dropFolder, mode: .automatic, addedAt: now.addingTimeInterval(1)))
        for folder in folders {
            folder.baselinedAt = now
            context.insert(folder)
            for kind in OutputKind.allCases {
                let s = OutputSetting(kind: kind)
                context.insert(s)
                s.source = folder
            }
        }
        try context.save()
        return true
    }
}

extension PrakritiStore {
    /// An output added after the store was made (the podcast-ready episode, 10 Oct) gets its default
    /// setting on the Outputs screen and a setting in every folder, switched off, so the screens can
    /// show it and nothing starts making it on its own. Returns the kinds it added.
    @MainActor
    @discardableResult
    static func addMissingOutputKinds(_ context: ModelContext) throws -> [OutputKind] {
        let all = try context.fetch(FetchDescriptor<OutputSetting>())
        guard !all.isEmpty else { return [] }
        let defaults = all.filter { $0.source == nil && $0.recording == nil }
        var added: [OutputKind] = []
        for kind in OutputKind.allCases where !defaults.contains(where: { $0.kind == kind }) {
            context.insert(OutputSetting(kind: kind))
            added.append(kind)
        }
        for source in try context.fetch(FetchDescriptor<Source>()) {
            for kind in OutputKind.allCases where source.setting(for: kind) == nil {
                let setting = OutputSetting(kind: kind)
                context.insert(setting)
                setting.source = source
                if !added.contains(kind) { added.append(kind) }
            }
        }
        if !added.isEmpty { try context.save() }
        return added
    }
}

/// Which choices apply to a recording.
///
/// - **Whether** an output is made: the recording's own switch (set on its page), else its folder's
///   (Sources), else the default (Outputs, for files added by hand).
/// - **How** it is made (loudness, trim, intro and outro, channels, formats, the word list): the
///   recording's own settings, else the Outputs screen's. A folder chooses only which outputs it
///   makes. Reason: each folder holds a copy of every setting from the day it was added, and until
///   10 Oct those copies won, so a loudness changed on the Outputs screen never reached a watched
///   folder's recordings (the screen showed one number and the episode was made at another).
enum OutputResolver {
    /// The setting whose switch decides whether `kind` is made.
    static func choice(for kind: OutputKind, recording: Recording?, source: Source?, defaults: [OutputSetting]) -> OutputSetting? {
        if let own = recording?.outputSettings.first(where: { $0.kind == kind }) { return own }
        if let folder = (source ?? recording?.source)?.outputSettings.first(where: { $0.kind == kind }) { return folder }
        return defaults.first { $0.kind == kind && $0.source == nil && $0.recording == nil }
    }

    /// The setting `kind` is made with: the recording's own, else the Outputs screen's.
    static func details(for kind: OutputKind, recording: Recording?, defaults: [OutputSetting]) -> OutputSetting? {
        if let own = recording?.outputSettings.first(where: { $0.kind == kind }) { return own }
        return defaults.first { $0.kind == kind && $0.source == nil && $0.recording == nil }
    }

    static func isOn(_ kind: OutputKind, recording: Recording?, source: Source?, defaults: [OutputSetting]) -> Bool {
        kind.isAvailable && choice(for: kind, recording: recording, source: source, defaults: defaults)?.isOn == true
    }

    /// The outputs that would be made for this recording right now. An output that cannot be made
    /// yet (not built, or waiting for its model) is never made, whatever a stored switch says.
    static func outputsToMake(recording: Recording?, source: Source?, defaults: [OutputSetting]) -> [OutputKind] {
        OutputKind.available.filter { isOn($0, recording: recording, source: source, defaults: defaults) }
    }
}

extension OutputResolver {
    /// The podcast-ready settings a recording is made with (11 Oct). How it sounds (layout, bitrate,
    /// noise reduction), the AI voice line and explicit are the episode's: the recording's own settings,
    /// else the Outputs screen's. What the show is called, who hosts it, its artwork, how it numbers its
    /// episodes and the call to action that closes its notes belong to the show, so they always come
    /// from the Outputs screen. Reason: a recording given its own choices kept a frozen copy of them, so
    /// a show name or call to action typed on the Outputs screen afterwards never reached it (found by
    /// the episode text's acceptance, 11 Oct; it is the flow BUILD-LOG gives Ivan for episode 1).
    static func podcastReady(recording: Recording?, defaults: [OutputSetting]) -> PodcastReadySettings {
        var settings = details(for: .podcastReady, recording: recording, defaults: defaults)?.podcastReadySettings ?? PodcastReadySettings()
        if let show = defaults.first(where: { $0.kind == .podcastReady && $0.source == nil && $0.recording == nil })?.podcastReadySettings {
            settings.showName = show.showName
            settings.hostName = show.hostName
            settings.artworkPath = show.artworkPath
            settings.numbering = show.numbering
            settings.callToAction = show.callToAction
        }
        return settings
    }
}

/// The privacy lock: a class, or anything with Serenity in it, only ever reaches a model on this
/// Mac. If the chosen provider sends text out, LM Studio is used instead, and the UI says so.
enum ModelRouting {
    static func provider(chosen: ModelProvider, for recording: Recording?) -> ModelProvider {
        guard let recording, recording.isPrivacyLocked, !chosen.isLocal else { return chosen }
        return .lmStudio
    }

    static func isOverridden(chosen: ModelProvider, for recording: Recording?) -> Bool {
        provider(chosen: chosen, for: recording) != chosen
    }
}
