import FluidAudio
import Foundation

// Telling voices apart on one mixed track (v2 part M6b, docs/v2/PLAN.md M6, research-people.md 2.5): FluidAudio's
// offline diarizer (pyannote segmentation, WeSpeaker embeddings, VBx grouping), pinned at 0.15.5, the version
// Hark resolves. It is the fallback: a recording with a microphone on its own track is read from its tracks
// instead (TrackActivity), because a mixed track can only be guessed at.
//
// Three rules, each enforced here and tested (PeopleTests):
// - `OfflineDiarizerConfig.Export.embeddingsPath` stays nil in every configuration built (`configuration()`), and
//   chunk embeddings stay off. When set, FluidAudio writes every embedding to disk: a voice print of everyone in
//   the room, students included.
// - Only times leave this file. The result's `speakerDatabase` (each voice's average embedding) and every
//   segment's own embedding are dropped before `diarize` returns; they live in memory for the length of the call.
// - Nothing is downloaded. FluidAudio's offline mode is switched on before its models load, so models missing from
//   `~/Library/Application Support/FluidAudio/Models/speaker-diarization` are an error, never a fetch; and the
//   manager's `prepareModels`, which on a failed load deletes that folder and downloads it again, is never called
//   (the folder is Hark's too).

enum Diarizer {
    struct Failure: Error, Sendable {
        let reason: String
    }

    /// The only configuration Prakriti builds: FluidAudio's community defaults with overlapping speech kept, no
    /// embeddings exported anywhere, no chunk embeddings kept.
    ///
    /// Two defaults are changed, for one measured reason (13 Oct, two-people-mixed.mp4, where a second voice speaks
    /// only over the teacher, 0:30 to 0:48.5): with FluidAudio's defaults the second voice vanished into the first
    /// (one voice, 85.5 s), because embeddings were taken only from speech nobody overlaps (`excludeOverlap`) and every
    /// moment was given to one voice (`exclusiveSegments`). With both off it found Voice 2 from 29.9 s to 48.5 s and
    /// left the teacher at 81.9 s. A voice that only ever speaks over the teacher is exactly a student heard while the
    /// teacher talks, and missing it would open the privacy lock; so overlap is kept, which errs toward hearing
    /// someone else (BUILD-LOG "v2 part M6b").
    static func configuration() -> OfflineDiarizerConfig {
        var config = OfflineDiarizerConfig.default
        config.postProcessing.exclusiveSegments = false
        config.embedding.excludeOverlap = false
        config.export = .none
        config.exposeChunkEmbeddings = false
        return config
    }

    /// Every configuration this file can build, for the test that reads `embeddingsPath` from each (docs/v2/PLAN.md
    /// M6 check 1).
    static var embeddingsPathOfEveryConfiguration: [String?] {
        [configuration().export.embeddingsPath, configuration().embeddingExportPath]
    }

    static var chunkEmbeddingsOfEveryConfiguration: [Bool] { [configuration().exposeChunkEmbeddings] }

    /// Where FluidAudio keeps the diarizer's models (Hark put them there), and the files it needs.
    static var modelsFolder: URL {
        OfflineDiarizerModels.defaultModelsDirectory().appending(path: "speaker-diarization", directoryHint: .isDirectory)
    }

    static let requiredModels = ["Segmentation.mlmodelc", "FBank.mlmodelc", "Embedding.mlmodelc", "PldaRho.mlmodelc", "plda-parameters.json"]

    /// The models are on this Mac.
    static var modelsPresent: Bool {
        requiredModels.allSatisfy { FileManager.default.fileExists(atPath: modelsFolder.appending(path: $0).path) }
    }

    /// Who speaks when in 16 kHz mono samples, as times only. Voices are numbered 1, 2... in the order FluidAudio
    /// first hears them; `VoicesFound.from` renumbers them by speaking time.
    static func diarize(_ samples: [Float], progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> [VoiceSegment] {
        guard modelsPresent else {
            throw Failure(reason: "The models that tell voices apart are not on this Mac (\(modelsFolder.path)), and Prakriti does not download them by itself.")
        }
        guard samples.count >= 16_000 else { return [] }
        ModelHub.offlineMode = true
        let models: OfflineDiarizerModels
        do {
            models = try await OfflineDiarizerModels.load(from: OfflineDiarizerModels.defaultModelsDirectory())
        } catch {
            throw Failure(reason: "The models that tell voices apart could not be opened: \(error.localizedDescription)")
        }
        let manager = OfflineDiarizerManager(config: configuration())
        manager.initialize(models: models)
        let result: DiarizationResult
        do {
            result = try await manager.process(audio: samples, progressCallback: { done, total in
                if total > 0 { progress(Double(done) / Double(total)) }
            })
        } catch {
            throw Failure(reason: "Voices could not be told apart: \(error.localizedDescription)")
        }
        // Times only: the speaker database and each segment's embedding are left behind with `result`.
        var ids: [String: Int] = [:]
        var segments: [VoiceSegment] = []
        for segment in result.segments.sorted(by: { $0.startTimeSeconds < $1.startTimeSeconds }) {
            let id = ids[segment.speakerId] ?? (ids.count + 1)
            ids[segment.speakerId] = id
            segments.append(VoiceSegment(start: PeopleFile.round(Double(segment.startTimeSeconds)),
                                         end: PeopleFile.round(Double(segment.endTimeSeconds)), voice: id))
        }
        return segments
    }
}
