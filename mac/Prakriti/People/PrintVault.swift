import CryptoKit
import Foundation
import Security

// The sealed vault for the gallery's prints (v2 part M7a, docs/v2/PLAN.md M7, research-people.md 5.2 and 5.4).
//
// - Each named person's face crops and voice prints are sealed with AES-GCM (CryptoKit) under that person's own
//   256-bit key. The key lives only in the login Keychain (service `studio.therowan.prakriti.app.people`, account =
//   the person's id), never in a file, a preference or the store. Destroying the key makes every sealed copy
//   unreadable, including one that slipped into a backup.
// - The whole `People/` folder is excluded from Time Machine (`isExcludedFromBackup`), so a forgotten print does not
//   live on in an old backup.
// - Forget destroys the key first, then proves that every sealed file of the person fails to open, then deletes the
//   files and the person's folders, and reports what it found. Apple's face index and its rebuild are part M7b.
//
// Part M7a builds the vault and Forget; nothing in M7a seals anything (recognition, which learns, is M7b), so on
// Ivan's Mac `People/Faces` and `People/Voices` stay absent (PLAN M6 check 7, M7 check 2). Files under `People/`
// never reach the network (`RulesTests.testFaceWorkCannotReachTheNetwork`).

/// Where a person's key is kept. The live copy, a development copy and the tests each use their own Keychain service,
/// so a test or a development run can never read or destroy a key of the live gallery.
struct VaultKeys: Sendable, Equatable {
    let service: String

    static let live = VaultKeys(service: "studio.therowan.prakriti.app.people")
    static let development = VaultKeys(service: "studio.therowan.prakriti.app.people.development")
    static let testing = VaultKeys(service: "studio.therowan.prakriti.app.tests.people")

    static func forMode(_ mode: AppMode, testing: Bool) -> VaultKeys {
        testing ? .testing : (mode == .live ? .live : .development)
    }

    private func query(_ person: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: person.uuidString]
    }

    struct Failure: Error, Sendable, Equatable { let status: OSStatus }

    /// The person's key, or nil when there is none (never made, or destroyed).
    func key(for person: UUID) -> SymmetricKey? {
        var query = query(person)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data, data.count == 32 else { return nil }
        return SymmetricKey(data: data)
    }

    /// The person's key, made once and kept in the login Keychain. "After first unlock", not "when unlocked", so the
    /// overnight watcher still works with the screen locked (research-people.md 5.2); never synchronized.
    func keyMakingIfNeeded(for person: UUID) throws -> SymmetricKey {
        if let key = key(for: person) { return key }
        let key = SymmetricKey(size: .bits256)
        var add = query(person)
        add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        add[kSecAttrLabel as String] = "Prakriti: People vault key"
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrSynchronizable as String] = false
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(status: status) }
        return key
    }

    /// Destroys the person's key. True when no key is left afterwards.
    @discardableResult
    func destroy(_ person: UUID) -> Bool {
        let status = SecItemDelete(query(person) as CFDictionary)
        return (status == errSecSuccess || status == errSecItemNotFound) && key(for: person) == nil
    }
}

/// What the vault holds: a face crop or a voice print.
enum VaultKind: String, Sendable, CaseIterable {
    case face, voice

    var folderName: String { self == .face ? "Faces" : "Voices" }
}

/// The sealed vault of one mode (`<Application Support>/People/Faces` and `Voices`, one folder per person).
struct PrintVault: Sendable {
    let folders: PeopleFolders
    let keys: VaultKeys

    struct Failure: Error, Sendable, Equatable { let reason: String }

    func folder(_ kind: VaultKind) -> URL { folders.people.appending(path: kind.folderName, directoryHint: .isDirectory) }
    func folder(_ kind: VaultKind, person: UUID) -> URL { folder(kind).appending(path: person.uuidString, directoryHint: .isDirectory) }

    /// Makes `People/` if it is not there and excludes it from Time Machine. Run at every launch and before anything is
    /// sealed. Returns whether the folder reads back as excluded.
    @discardableResult
    func prepare() -> Bool {
        let people = folders.people
        try? FileManager.default.createDirectory(at: people, withIntermediateDirectories: true)
        var url = people
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return Self.isExcludedFromBackup(people)
    }

    static func isExcludedFromBackup(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup) == true
    }

    /// Seals `data` for a person under their own key, into a new file named by a UUID (never a file name, a time or
    /// anything about the recording). Written whole, so a crash leaves either nothing or a sealed file.
    @discardableResult
    func seal(_ data: Data, kind: VaultKind, person: UUID) throws -> URL {
        prepare()
        let key = try keys.keyMakingIfNeeded(for: person)
        guard let combined = try AES.GCM.seal(data, using: key).combined else { throw Failure(reason: "The sealed box could not be made.") }
        let folder = folder(kind, person: person)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: UUID().uuidString + ".sealed")
        try combined.write(to: file, options: [.atomic])
        return file
    }

    /// Opens one sealed file of a person. Throws when the key is gone or the file was not sealed under it.
    func open(_ file: URL, person: UUID) throws -> Data {
        guard let key = keys.key(for: person) else { throw Failure(reason: "No key for this person: the file cannot be opened.") }
        let box = try AES.GCM.SealedBox(combined: try Data(contentsOf: file))
        return try AES.GCM.open(box, using: key)
    }

    /// Every sealed file of a person, faces then voices.
    func sealedFiles(person: UUID) -> [URL] {
        VaultKind.allCases.flatMap { kind -> [URL] in
            let files = (try? FileManager.default.contentsOfDirectory(at: folder(kind, person: person), includingPropertiesForKeys: nil)) ?? []
            return files.filter { $0.pathExtension == "sealed" }.sorted { $0.path < $1.path }
        }
    }

    /// Whether anything is kept for the person: a sealed file or a key.
    func holdsAnything(person: UUID) -> Bool {
        !sealedFiles(person: person).isEmpty || keys.key(for: person) != nil
    }

    /// What Forget found, as its proof (PLAN M7: "then prove it").
    struct ForgetProof: Sendable, Equatable {
        /// Sealed files found before deleting.
        var sealedFiles = 0
        /// Of those, how many failed to open once the key was destroyed (must equal `sealedFiles`).
        var failedToOpen = 0
        /// No key is left in the Keychain.
        var keyGone = false
        /// Files of the person left under `Faces` and `Voices` afterwards (must be 0).
        var filesLeft = 0

        var holds: Bool { keyGone && failedToOpen == sealedFiles && filesLeft == 0 }

        /// One plain sentence for Activity. Never a name: the caller adds who.
        var line: String {
            let files = sealedFiles == 0 ? "No sealed file was kept" : "\(Format.count(sealedFiles, "sealed file")) \(sealedFiles == 1 ? "was" : "were") kept"
            return "\(files); the key is \(keyGone ? "destroyed" : "STILL THERE"), \(failedToOpen) of \(sealedFiles) failed to open after it, and \(filesLeft) \(filesLeft == 1 ? "file is" : "files are") left."
        }
    }

    /// Forget Face and Voice, for the vault: destroy the key, prove every sealed file now fails to open, delete them and
    /// the person's folders, and remove `Faces` and `Voices` when nobody is left in them (so they never sit empty).
    @discardableResult
    func forget(person: UUID) -> ForgetProof {
        var proof = ForgetProof()
        let files = sealedFiles(person: person)
        proof.sealedFiles = files.count
        proof.keyGone = keys.destroy(person)
        for file in files where (try? open(file, person: person)) == nil { proof.failedToOpen += 1 }
        for kind in VaultKind.allCases {
            try? FileManager.default.removeItem(at: folder(kind, person: person))
            let left = (try? FileManager.default.contentsOfDirectory(atPath: folder(kind).path)) ?? []
            if left.filter({ !$0.hasPrefix(".") }).isEmpty { try? FileManager.default.removeItem(at: folder(kind)) }
        }
        proof.filesLeft = sealedFiles(person: person).count
        return proof
    }
}
