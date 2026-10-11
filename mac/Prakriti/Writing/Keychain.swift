import Foundation
import Security

/// The Claude API key, kept in the login Keychain as a generic password and nowhere else: never in
/// a file, the preferences, the store or a log (the build's rule, and SCOPE: secrets in the Keychain,
/// never in a plist). Read only when a run will actually call the Claude API.
struct KeyStore: Sendable {
    let service: String
    let account: String

    /// Ivan's key, shared by the live and development copies (same person, same Mac).
    static let claude = KeyStore(service: "studio.therowan.prakriti.app.claude-api", account: "api-key")
    /// Tests use their own item, so they never read or replace Ivan's key.
    static let testing = KeyStore(service: "studio.therowan.prakriti.app.tests.claude-api", account: "api-key")

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
        add[kSecAttrLabel as String] = "Prakriti: Claude API key"
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
