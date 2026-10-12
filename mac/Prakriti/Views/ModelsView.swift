import SwiftUI

/// Which model does which job, where each one runs, and a test button for each (milestone 6).
struct ModelsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                PageIntro(text: "Which model writes for each task. Models on this Mac keep everything here. The Claude API sends text to Anthropic, so only a recording marked as a talk, without Serenity in it, ever goes there.")
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
                }
            } header: {
                SectionHeader("Tasks")
            }

            Section {
                Label {
                    Text("Only a recording marked as a talk can use the Claude API. A class, a conversation, a test, a recording not marked yet, or one whose transcript says \"Serenity\" always uses a model on this Mac. If a task above is set to the Claude API, LM Studio does that task for these recordings instead, and the recording's page and its show notes say so.")
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
                            note: "Optional. The key is kept in the Keychain, never in a file. Never used for a class or anything with Serenity in it.")
                ClaudeKeyRow()
                FieldRow(label: "Model", text: $settings.claudeModel, prompt: AppSettings.defaultClaudeModel)
                TestRow(provider: .claudeAPI, title: "Test Claude API")
            } header: {
                SectionHeader("Claude API")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
        .onAppear { model.refreshClaudeKey() }
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

/// The Claude API key: whether one is in the Keychain, and a field to add or replace it. The key is
/// never shown once saved, and never read back into the window.
struct ClaudeKeyRow: View {
    @Environment(AppModel.self) private var model
    @State private var key = ""
    @State private var problem: String?

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    SecureField("API key", text: $key, prompt: Text(model.claudeKeyAdded ? "Paste a new key to replace it" : "Paste a key"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(AppFont.body)
                        .frame(maxWidth: 280)
                    Button("Save in Keychain") {
                        problem = model.saveClaudeKey(key)
                        if problem == nil { key = "" }
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                    if model.claudeKeyAdded {
                        Button("Remove Key") { model.removeClaudeKey() }
                    }
                }
                if let problem {
                    Text(problem).font(AppFont.secondary).foregroundStyle(.appSecondary)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Key").font(AppFont.body)
                Text(model.claudeKeyAdded ? "Kept in the Keychain." : "No key added.").font(AppFont.secondary).foregroundStyle(.appSecondary)
            }
        }
    }
}
