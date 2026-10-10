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

/// Which setting applies to a recording: its own, else its folder's, else the default.
enum OutputResolver {
    static func setting(for kind: OutputKind, recording: Recording?, source: Source?, defaults: [OutputSetting]) -> OutputSetting? {
        if let own = recording?.outputSettings.first(where: { $0.kind == kind }) { return own }
        if let folder = (source ?? recording?.source)?.outputSettings.first(where: { $0.kind == kind }) { return folder }
        return defaults.first { $0.kind == kind && $0.source == nil && $0.recording == nil }
    }

    /// The outputs that would be made for this recording right now. Not-built outputs are never
    /// made, whatever a stored switch says.
    static func outputsToMake(recording: Recording?, source: Source?, defaults: [OutputSetting]) -> [OutputKind] {
        OutputKind.built.filter { setting(for: $0, recording: recording, source: source, defaults: defaults)?.isOn == true }
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
