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

    /// First launch: the default output choices, and the one folder this mode may use.
    /// Development mode adds only ~/Prakriti/Dev/Drop. The live Studio Recordings folder is added
    /// at the switch-over (milestone 3), never before: engine v0 owns it until then.
    @MainActor
    static func seedIfEmpty(_ context: ModelContext, paths: AppPaths, now: Date) throws -> Bool {
        let existing = try context.fetchCount(FetchDescriptor<OutputSetting>())
        guard existing == 0 else { return false }
        for kind in OutputKind.allCases {
            context.insert(OutputSetting(kind: kind))
        }
        let drop = Source(name: paths.mode == .development ? "Test drop folder" : "Drop folder",
                          path: paths.drop.path, kind: .dropFolder, mode: .automatic, addedAt: now)
        context.insert(drop)
        for kind in OutputKind.allCases {
            let s = OutputSetting(kind: kind)
            context.insert(s)
            s.source = drop
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
