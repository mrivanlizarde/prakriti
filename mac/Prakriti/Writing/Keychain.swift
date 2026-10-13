import Foundation
import Security

/// A cloud provider's API key (Anthropic, and OpenAI since v2 part M5b), kept in the login Keychain as a
/// generic password and nowhere else: never in a file, the preferences, the store or a log (the build's
/// rule, and SCOPE: secrets in the Keychain, never in a plist). Read only when a run will actually call
/// that provider.
struct KeyStore: Sendable {
    let service: String
    let account: String
    var label: String = "Prakriti: API key"

    /// Ivan's Anthropic key, shared by the live and development copies (same person, same Mac). The service
    /// keeps v1's name ("claude-api") so a key saved before M5b is still found.
    static let claude = KeyStore(service: "studio.therowan.prakriti.app.claude-api", account: "api-key", label: "Prakriti: Anthropic API key")
    /// The OpenAI key (v2 part M5b).
    static let openAI = KeyStore(service: "studio.therowan.prakriti.app.openai-api", account: "api-key", label: "Prakriti: OpenAI API key")
    /// Tests use their own items, so they never read or replace Ivan's keys.
    static let testing = KeyStore(service: "studio.therowan.prakriti.app.tests.claude-api", account: "api-key")
    static let testingOpenAI = KeyStore(service: "studio.therowan.prakriti.app.tests.openai-api", account: "api-key")

    /// The key for a cloud provider; nil for one on this Mac. `testing` picks the tests' own items.
    static func forProvider(_ provider: ModelProvider, testing: Bool) -> KeyStore? {
        switch provider {
        case .claudeAPI: testing ? Self.testing : .claude
        case .openAI: testing ? testingOpenAI : .openAI
        case .lmStudio, .appleOnDevice, .ollama: nil
        }
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// The key, or nil when there is none.
    func read() -> String? {
        var query = self.query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    /// Whether a key is there, without reading it.
    var exists: Bool {
        var query = self.query
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    struct Failure: Error, Sendable { let status: OSStatus }

    /// Saves the key, replacing any there.
    func save(_ key: String) throws {
        let data = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw Failure(status: update) }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrLabel as String] = label
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    /// Removes the key. Nothing there is not an error.
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }
}
