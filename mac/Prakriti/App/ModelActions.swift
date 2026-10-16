import Foundation
import SwiftData

// What Ivan does with the models (milestone 6; Anthropic and OpenAI since v2 part M5b): test each provider,
// keep the cloud keys in the Keychain and load their model lists, write a recording's titles, show notes and
// chapters again, and take a written title or the written notes onto the recording. Each leaves one line in Activity (numbers and names of
// models only, never the words written).
extension AppModel {
    private func label(_ recording: Recording) -> String {
        "\(Format.dayLabel(recording.sessionDate)) (\(recording.fileName))"
    }

    /// The test button for one provider. It runs a one-line request with no recording in it; a cloud
    /// provider's test sends only `PrivacyLock.keyCheck()` (fixed words, no recording).
    func testProvider(_ provider: ModelProvider) {
        guard providerChecks[provider]?.state != .checking else { return }
        providerChecks[provider] = ProviderCheck(state: .checking, line: provider == .lmStudio
                                                 ? "Testing. If the model is not loaded, Prakriti loads it first, which takes a few seconds."
                                                 : "Testing.", at: now())
        var setup = runner.writingSetup()
        if provider == .claudeAPI { setup.claudeKey = keyStore(for: .claudeAPI)?.read() }
        if provider == .openAI { setup.openAIKey = keyStore(for: .openAI)?.read() }
        let local = provider.isLocal ? setup.makeClient(provider, setup) : nil
        let cloud = provider.isLocal ? nil : setup.makeCloudClient(provider, setup)
        Task { @MainActor in
            let check = if let local { await local.check() } else { await cloud?.check() ?? ProviderCheck(state: .problem, line: "Nothing was sent.", at: Date()) }
            providerChecks[provider] = check
            if check.keyRejected { keysRejected.insert(provider) } else if check.state == .ok { keysRejected.remove(provider) }
            record("Tested \(provider.title): \(check.line)", level: check.state == .problem || check.keyRejected ? .attention : .info)
        }
    }

    /// Re-reads which cloud providers have a key in the Keychain (without reading the keys).
    func refreshKeys() {
        keysAdded = Set(ModelProvider.cloud.filter { keyStore(for: $0)?.exists == true })
    }

    /// Saves a cloud provider's key in the Keychain, then loads its model list. Returns the problem, or nil.
    @discardableResult
    func saveKey(_ key: String, for provider: ModelProvider) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Paste a key first." }
        guard let store = keyStore(for: provider) else { return "\(provider.title) runs on this Mac and needs no key." }
        do {
            try store.save(trimmed)
            refreshKeys()
            keysRejected.remove(provider)
            providerChecks[provider] = nil
            record("An \(provider.title) key was saved in the Keychain. It is used only for tasks set to \(provider.title), and only for recordings the privacy lock lets out.")
            loadModels(for: provider)
            return nil
        } catch {
            return "The Keychain did not take the key (\((error as? KeyStore.Failure).map { "error \($0.status)" } ?? error.localizedDescription))."
        }
    }

    func removeKey(for provider: ModelProvider) {
        try? keyStore(for: provider)?.remove()
        refreshKeys()
        keysRejected.remove(provider)
        providerChecks[provider] = nil
        cloudModelLists[provider] = nil
        record("The \(provider.title) key was removed from the Keychain.")
    }

    /// Fills a cloud provider's model pop-up from its own list (`GET /v1/models`, free). Sends the key and
    /// nothing else; with no key, nothing is sent.
    func loadModels(for provider: ModelProvider) {
        guard ModelProvider.cloud.contains(provider), cloudModelLists[provider]?.state != .loading else { return }
        guard let key = keyStore(for: provider)?.read() else {
            cloudModelLists[provider] = CloudModelList(state: .noKey)
            return
        }
        cloudModelLists[provider] = CloudModelList(state: .loading, models: cloudModelLists[provider]?.models ?? [])
        let session = modelListSession
        Task { @MainActor in
            do {
                let models = provider == .openAI ? try await OpenAIClient.models(key: key, session: session)
                                                 : try await AnthropicClient.models(key: key, session: session)
                cloudModelLists[provider] = CloudModelList(state: .loaded, models: models)
                keysRejected.remove(provider)
                if provider == .openAI, settings.openAIModel.isEmpty, let first = models.first { settings.openAIModel = first.id }
            } catch let failure as ModelFailure {
                if failure.kind == .keyRejected { keysRejected.insert(provider) }
                cloudModelLists[provider] = CloudModelList(state: failure.kind == .keyRejected ? .rejected : .problem, line: failure.reason)
                record("\(provider.title)'s list of models could not be read: \(failure.reason)", level: .attention)
            } catch {
                cloudModelLists[provider] = CloudModelList(state: .problem, line: "The list of models could not be read.")
            }
        }
    }

    /// Write Again can run: something is made, its transcript is there, and nothing is running on it.
    func canWrite(_ recording: Recording) -> Bool {
        guard recording.status == .readyForYourYes || recording.status.isApproved,
              !runner.isWaiting(recording), !runner.isCurrent(recording), let folder = recording.outputFolder else { return false }
        return FileManager.default.fileExists(atPath: URL(fileURLWithPath: folder).appending(path: TranscriptFiles.asHeard).path)
    }

    /// Writes the titles, show notes and chapters again, from the transcript already made. Takes its
    /// turn in line, like any other work.
    func writeAgain(_ recording: Recording) {
        guard canWrite(recording) else { return }
        runner.enqueue(recording, trigger: .writeAgain)
    }

    /// The podcast-ready settings this recording is made with: its own, else the Outputs screen's.
    func podcastReadySettings(for recording: Recording) -> PodcastReadySettings {
        OutputResolver.podcastReady(recording: recording, defaults: defaultSettings())
    }

    /// The highest episode number on any other recording, to say on the page (never filled in).
    func highestEpisodeNumber(excluding recording: Recording) -> Int? {
        ((try? context.fetch(FetchDescriptor<Recording>())) ?? []).filter { $0.id != recording.id }.compactMap(\.episodeNumber).max()
    }

    /// Update Podcast-Ready Files can run: they exist, the MP3 is in its folder, nothing is running on
    /// it, and it is not a class (a class is never made ready to upload).
    func canUpdatePodcastReady(_ recording: Recording) -> Bool {
        guard recording.status == .readyForYourYes || recording.status.isApproved, PodcastPackage.refusal(kind: recording.kind) == nil,
              !runner.isWaiting(recording), !runner.isCurrent(recording),
              let folder = recording.outputFolder, let ready = recording.podcastReady else { return false }
        return FileManager.default.fileExists(atPath: URL(fileURLWithPath: folder).appending(path: PodcastPackage.folderName).appending(path: ready.fileName).path)
    }

    /// The podcast-ready files were made with an older title, notes, show name, host, artwork,
    /// episode number or set of written notes than the recording has now.
    func podcastReadyIsOutOfDate(_ recording: Recording) -> Bool {
        guard let ready = recording.podcastReady else { return false }
        return ready.fingerprint != PodcastPackage.fingerprint(settings: podcastReadySettings(for: recording), facts: recording.podcastFacts, written: recording.written)
    }

    /// Writes the podcast-ready files again around the audio already made. Takes its turn in line.
    func updatePodcastReady(_ recording: Recording) {
        guard canUpdatePodcastReady(recording) else { return }
        runner.enqueue(recording, trigger: .packageAgain)
    }

    /// The episode number and season, set on the recording's page.
    func setEpisodeNumbers(episode: Int?, season: Int?, for recording: Recording) {
        guard recording.episodeNumber != episode || recording.seasonNumber != season else { return }
        recording.episodeNumber = episode
        recording.seasonNumber = season
        record("\(label(recording)): episode " + (episode.map(String.init) ?? "not set") + ", season " + (season.map(String.init) ?? "not set") + ".")
        try? context.save()
    }

    /// Takes one of the written title options as the recording's title.
    func useTitle(_ title: String, for recording: Recording) {
        guard recording.title != title else { return }
        recording.title = title
        record("\(label(recording)): a written title option is now its title.")
        changedAfterApproval(recording, what: "its title")
        try? context.save()
    }

    /// Takes the written show notes as the recording's notes, replacing what was there.
    func useNotes(_ notes: String, for recording: Recording) {
        guard recording.notes != notes else { return }
        recording.notes = notes
        record("\(label(recording)): the written show notes are now its notes.")
        changedAfterApproval(recording, what: "its notes")
        try? context.save()
    }

    /// The provider a task really uses for this recording: the privacy lock (PrivacyLock.decide) turns a
    /// cloud choice into LM Studio for a locked recording.
    func provider(for task: ModelTask, recording: Recording?) -> ModelProvider {
        ModelRouting.provider(chosen: settings.provider[task] ?? .lmStudio, for: recording)
    }
}
