import Foundation
import XCTest
@testable import Prakriti

/// v2 part M5b, PLAN M5 check 6 (`make accept-providers`): each cloud key tested against its provider's free
/// `GET /v1/models`, then titles, show notes and chapters written once per provider for
/// `synthetic-transcript.json` (a made-up talk naming no real person), the answer passing `WritingCheck`.
///
/// It spends a few cents, so it runs only with Ivan's yes (`YES=1`), and it reads keys only from the TESTS'
/// Keychain items (`studio.therowan.prakriti.app.tests.claude-api` and `...tests.openai-api`), never from the
/// items the app uses: PLAN section 11 says never to read or test with Ivan's real key. Without a yes or
/// without a key in those items, the provider is reported SKIPPED, not failed.
@MainActor
final class ProvidersAcceptanceTests: XCTestCase {
    func testEachKeyAgainstItsProviderAndOneWrite() async throws {
        guard ProcessInfo.processInfo.environment["PRAKRITI_ACCEPTANCE"] == "providers" else { throw XCTSkip("Run with make accept-providers") }
        let yes = ProcessInfo.processInfo.environment["PRAKRITI_PROVIDERS_YES"] == "1"
        var report = ["make accept-providers, \(Date().formatted(date: .abbreviated, time: .shortened))",
                      "Keys read only from the tests' Keychain items; the app's own items are never read.", ""]
        defer {
            let folder = SnapshotRenderer.milestoneFolder()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? report.joined(separator: "\n").appending("\n").write(to: folder.appending(path: "acceptance-providers.txt"), atomically: true, encoding: .utf8)
        }
        for provider in ModelProvider.cloud {
            guard let store = KeyStore.forProvider(provider, testing: true) else { continue }
            guard yes else { report.append("\(provider.title): SKIPPED. No yes on the cost (run with YES=1 after Ivan's yes)."); continue }
            guard let key = store.read() else {
                report.append("\(provider.title): SKIPPED. No key in the tests' Keychain item \(store.service).")
                continue
            }
            let models = provider == .openAI ? try await OpenAIClient.models(key: key) : try await AnthropicClient.models(key: key)
            report.append("\(provider.title): GET /v1/models listed \(Format.count(models.count, "model")) that work with Prakriti: \(models.prefix(8).map(\.id).joined(separator: ", ")).")
            XCTAssertFalse(models.isEmpty, provider.title)
            let chosen = provider == .openAI ? (models.first?.id ?? "") : AppSettings.defaultClaudeModel

            let source = ProviderTests.fixtures.appending(path: "synthetic-transcript.json")
            let folder = FileManager.default.temporaryDirectory.appending(path: "prakriti-accept-providers-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            try FileManager.default.copyItem(at: source, to: folder.appending(path: TranscriptFiles.asHeard))
            var input = try XCTUnwrap(WritingInput.from(folder: folder, clock: nil, duration: 0, applyLexicon: false, label: "Synthetic",
                                                        fileName: "synthetic.json", kind: .talk, knownSerenity: false))
            input.people = PeopleFacts(checked: true, named: [ProviderTests.teacher()])
            var setup = WritingSetup()
            setup.providers = [.writing: provider, .tagging: .appleOnDevice, .summarizing: .appleOnDevice]
            setup.maxAttempts = 1
            if provider == .openAI { setup.openAIKey = key; setup.openAIModel = chosen } else { setup.claudeKey = key; setup.claudeModel = chosen }
            let outcome = try await Writer(setup: setup, log: nil).write(input)
            let package = outcome.package
            report.append("\(provider.title), \(chosen): " + (package.map { "written in \(Format.length($0.writingSeconds)), \(Format.count($0.titles.count, "title")), \(Format.count($0.chapters.count, "chapter")), \(Format.count($0.checklist.count, "quote")) found word for word. PASS." }
                                                          ?? "FAIL: \(outcome.problem ?? "no answer")"))
            XCTAssertNotNil(package, outcome.problem ?? provider.title)
        }
    }
}
