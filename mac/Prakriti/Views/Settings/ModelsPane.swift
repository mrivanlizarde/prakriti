import SwiftUI

/// Settings, Models (v2 part M5b, design spec 3.13): what moves to a cloud model and what never does, this
/// Mac's verdict, which provider does each task, the privacy lock, and each provider with its address, key,
/// model and test button. Anthropic and OpenAI keys live only in the Keychain; their model pop-ups are filled
/// from each provider's own list.
struct ModelsPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                PageIntro(text: "Models write the titles, show notes, chapters, tags and summaries, and read the parts of a talk when a direction asks. Transcribing, checking the sound and making the episode always happen on this Mac, and no recording ever leaves it. A cloud model reads only the words of a transcript.")
            }

            Section {
                let verdict = HardwareVerdict(model.hardware)
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verdict.headline).font(AppFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                        if let suggestion = verdict.suggestion {
                            Text(suggestion).font(AppFont.secondary).foregroundStyle(.appSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(verdict.appleIntelligence).font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: verdict.canRunWritingModel ? "checkmark.circle" : "exclamationmark.triangle").font(AppFont.body)
                }
            } header: {
                SectionHeader("This Mac")
            }

            Section {
                ForEach(ModelTask.allCases, id: \.self) { task in
                    Picker(selection: Binding(get: { settings.provider[task] ?? .lmStudio },
                                              set: { settings.provider[task] = $0 })) {
                        ForEach(ModelProvider.allCases, id: \.self) { provider in
                            Text(provider.title).tag(provider)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title).font(AppFont.body)
                            Text(task.summary).font(AppFont.secondary).foregroundStyle(.appSecondary)
                        }
                    }
                    .disabled(!task.isBuilt)
                }
            } header: {
                SectionHeader("Tasks")
            }

            Section {
                Label {
                    Text(PrivacyLock.settingsLine)
                        .font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.fill").font(AppFont.body)
                }
            } header: {
                SectionHeader("Privacy lock")
            }

            Section {
                ProviderRow(provider: .lmStudio, location: "On this Mac",
                            note: "The writing model. Prakriti loads it at a 65,536-token context so a whole transcript fits, with its thinking capped, and unloads it afterwards if it loaded it.")
                FieldRow(label: "Address", text: $settings.lmStudioAddress, prompt: AppSettings.defaultLMStudioAddress)
                FieldRow(label: "Model", text: $settings.lmStudioModel, prompt: AppSettings.defaultLMStudioModel)
                TestRow(provider: .lmStudio, title: "Test LM Studio")
            } header: {
                SectionHeader("LM Studio")
            }

            Section {
                ProviderRow(provider: .appleOnDevice, location: "On this Mac",
                            note: "Built into macOS. It reads a few thousand words at once: a long transcript is read in parts for tags and summaries, and refused for writing.")
                ValueRow(label: "Status", value: AppleOnDeviceClient.unavailableReason.map { _ in "Not available" }
                         ?? "Available, reads up to \(Format.number(AppleOnDeviceClient.contextSize)) tokens at once")
                if let reason = AppleOnDeviceClient.unavailableReason {
                    RowNote(reason)
                }
                TestRow(provider: .appleOnDevice, title: "Test Apple On-Device")
            } header: {
                SectionHeader("Apple on-device")
            }

            Section {
                ProviderRow(provider: .ollama, location: "On this Mac", note: "Optional. Name a model Ollama has downloaded to use it.")
                FieldRow(label: "Address", text: $settings.ollamaAddress, prompt: AppSettings.defaultOllamaAddress)
                FieldRow(label: "Model", text: $settings.ollamaModel, prompt: "None chosen")
                TestRow(provider: .ollama, title: "Test Ollama")
            } header: {
                SectionHeader("Ollama")
            }

            Section {
                ProviderRow(provider: .claudeAPI, location: "Sends text to Anthropic",
                            note: "Optional, with your own key. Claude Sonnet 5.5 costs less per call; Claude Opus 5.5 is the most careful. The test shows what a call cost.")
                KeyRow(provider: .claudeAPI)
                CloudModelRow(provider: .claudeAPI, selection: $settings.claudeModel)
                TestRow(provider: .claudeAPI, title: "Test Anthropic")
            } header: {
                SectionHeader("Anthropic")
            }

            Section {
                ProviderRow(provider: .openAI, location: "Sends text to OpenAI",
                            note: "Optional, with your own key. Only models that write text are listed.")
                KeyRow(provider: .openAI)
                CloudModelRow(provider: .openAI, selection: $settings.openAIModel)
                TestRow(provider: .openAI, title: "Test OpenAI")
            } header: {
                SectionHeader("OpenAI")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
        .onAppear {
            guard model.readsKeysOnAppear else { return }
            model.refreshKeys()
            for provider in ModelProvider.cloud where model.keysAdded.contains(provider) && model.cloudModelLists[provider] == nil {
                model.loadModels(for: provider)
            }
        }
    }
}

struct ProviderRow: View {
    let provider: ModelProvider
    let location: String
    let note: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: provider.isLocal ? "house" : "arrow.up.right.circle")
                .font(AppFont.body)
                .foregroundStyle(.appSecondary)
                .frame(width: Metrics.symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(location).font(AppFont.body)
                Text(note).font(AppFont.secondary).foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

/// A labeled text field for an address or a model name, saved as it is typed.
struct FieldRow: View {
    let label: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        LabeledContent {
            TextField(label, text: $text, prompt: Text(prompt))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(AppFont.path)
                .autocorrectionDisabled()
                .frame(maxWidth: 360)
        } label: {
            Text(label).font(AppFont.body)
        }
    }
}

/// A provider's test button and what it found, in one plain line with a symbol that differs by shape.
struct TestRow: View {
    let provider: ModelProvider
    let title: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let check = model.providerChecks[provider]
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let check {
                Image(systemName: Self.symbol(check.state))
                    .font(AppFont.body)
                    .foregroundStyle(check.state == .ok ? Color.accentColor : .secondary)
                    .frame(width: Metrics.symbolWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.line).font(AppFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if check.state != .checking {
                        Text("Tested at \(Format.clock(check.at)).").font(AppFont.secondary).foregroundStyle(.appSecondary)
                    }
                }
            } else {
                Text("Not tested yet.").font(AppFont.body).foregroundStyle(.appSecondary)
            }
            Spacer(minLength: 12)
            Button(title) { model.testProvider(provider) }
                .disabled(check?.state == .checking)
        }
        .padding(.vertical, 2)
    }

    static func symbol(_ state: ProviderCheck.State) -> String {
        switch state {
        case .checking: "circle.dotted"
        case .ok: "checkmark.circle.fill"
        case .notSetUp: "minus.circle"
        case .problem: "exclamationmark.triangle"
        }
    }
}

/// A cloud provider's key: "Saved in your Keychain" with Remove Key once saved (never shown again, never read
/// back into the window); a field and Save in Keychain when there is none, or when the provider refused it
/// (design spec 3.13 and its error table: "Anthropic did not accept this key. Check it and save it again.").
struct KeyRow: View {
    let provider: ModelProvider
    @Environment(AppModel.self) private var model
    @State private var key = ""
    @State private var problem: String?

    var body: some View {
        let saved = model.keysAdded.contains(provider)
        let rejected = model.keysRejected.contains(provider)
        LabeledContent {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    if !saved || rejected {
                        SecureField("API key", text: $key, prompt: Text(rejected ? "Paste a new key" : "Paste a key"))
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .font(AppFont.body)
                            .frame(minWidth: 200, maxWidth: 280)
                        Button("Save in Keychain") {
                            problem = model.saveKey(key, for: provider)
                            if problem == nil { key = "" }
                        }
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if saved {
                        Button("Remove Key") { model.removeKey(for: provider) }
                    }
                }
                if let problem {
                    Text(problem).font(AppFont.secondary).foregroundStyle(.appSecondary)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Key").font(AppFont.body)
                Label {
                    Text(Self.line(provider: provider, saved: saved, rejected: rejected))
                        .font(AppFont.secondary).foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: rejected ? "exclamationmark.triangle" : saved ? "checkmark.circle" : "minus.circle")
                        .font(AppFont.secondary).foregroundStyle(.appSecondary)
                }
            }
        }
    }

    static func line(provider: ModelProvider, saved: Bool, rejected: Bool) -> String {
        if rejected { return "\(provider.title) did not accept this key. Check it and save it again." }
        return saved ? "Saved in your Keychain." : "No key added. Nothing is sent to \(provider.title)."
    }
}

/// A cloud provider's model pop-up, filled from the provider's own list. The model already chosen stays in
/// the list even before the list is read, so a choice is never lost.
struct CloudModelRow: View {
    let provider: ModelProvider
    @Binding var selection: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let list = model.cloudModelLists[provider]
        var models = list?.models ?? []
        if !selection.isEmpty, !models.contains(where: { $0.id == selection }) { models.insert(CloudModel(id: selection, name: selection), at: 0) }
        return LabeledContent {
            VStack(alignment: .trailing, spacing: 6) {
                Picker("Model", selection: $selection) {
                    if selection.isEmpty { Text("None chosen").tag("") }
                    ForEach(models) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 280)
                .disabled(models.isEmpty)
                if model.keysAdded.contains(provider) {
                    Button("Read the List Again") { model.loadModels(for: provider) }
                        .disabled(list?.state == .loading)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Model").font(AppFont.body)
                Text(Self.line(provider: provider, list: list, hasKey: model.keysAdded.contains(provider)))
                    .font(AppFont.secondary).foregroundStyle(.appSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static func line(provider: ModelProvider, list: CloudModelList?, hasKey: Bool) -> String {
        guard hasKey else { return "Add a key to see \(provider.title)'s models." }
        switch list?.state {
        case .loading: return "Reading \(provider.title)'s list of models."
        case .loaded: return "\(Format.count(list?.models.count ?? 0, "model")) that \((list?.models.count ?? 0) == 1 ? "works" : "work") with Prakriti, from \(provider.title)'s own list."
        case .rejected, .problem: return list?.line ?? "The list of models could not be read."
        case .noKey: return "Add a key to see \(provider.title)'s models."
        case nil: return "The list is read when a key is saved."
        }
    }
}
