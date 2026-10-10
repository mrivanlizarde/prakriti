import SwiftUI

/// Which model does which job, and where each one runs.
struct ModelsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let settings = model.settings
        Form {
            Section {
                PageIntro(text: "Which model writes for each task. Models on this Mac keep everything here. The Claude API sends text to Anthropic, so classes and anything with Serenity in it never go there.")
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
                            Text(task.summary).font(AppFont.secondary).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                SectionHeader("Tasks")
            }

            Section {
                Label {
                    Text("A recording marked as a class, or with Serenity in it, always uses a model on this Mac. If a task above is set to the Claude API, LM Studio does that task for these recordings instead, and the recording's page says so.")
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
                            note: "The writing model. Loads at a 65,536-token context so a whole transcript fits.")
                ValueRow(label: "Address", value: settings.lmStudioAddress, monospaced: true)
                ValueRow(label: "Model", value: settings.lmStudioModel, monospaced: true)
            } header: {
                SectionHeader("LM Studio")
            }

            Section {
                ProviderRow(provider: .appleOnDevice, location: "On this Mac",
                            note: "Built into macOS. Only for short inputs; longer transcripts are split or refused.")
            } header: {
                SectionHeader("Apple on-device")
            }

            Section {
                ProviderRow(provider: .ollama, location: "On this Mac", note: "Optional. Not set up.")
            } header: {
                SectionHeader("Ollama")
            }

            Section {
                ProviderRow(provider: .claudeAPI, location: "Sends text to Anthropic",
                            note: "Optional. No key added. A key is kept in the Keychain, never in a file.")
            } header: {
                SectionHeader("Claude API")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
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
                .foregroundStyle(.secondary)
                .frame(width: Metrics.symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(location).font(AppFont.body)
                Text(note).font(AppFont.secondary).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
