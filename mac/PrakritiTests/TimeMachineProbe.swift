import Darwin
import Foundation

/// How the tests read a folder's Time Machine exclusion (v2 part M8b, fixes after the verifier).
///
/// Load-bearing: `/usr/bin/tmutil isexcluded` started from the XCTest host can hang for over an hour (sampled: waiting in
/// CFRunLoop), on this Mac since 14 Oct, on M7b's code too, while the same call from a shell answers in 0.1 s. A test that
/// waits on it never ends, so `make test` could never go green. What tmutil reads for a sticky exclusion is one extended
/// attribute on the folder itself, `com.apple.metadata:com_apple_backup_excludeItem`, a binary property list holding
/// "com.apple.backupd" (Foundation's `isExcludedFromBackup` writes exactly that). The tests read that attribute directly,
/// and still ask tmutil, but give it 10 s and say so when it does not answer instead of waiting forever.
enum TimeMachineProbe {
    static let attribute = "com.apple.metadata:com_apple_backup_excludeItem"

    /// The exclusion attribute's value ("com.apple.backupd" when excluded), or nil when the folder has none.
    static func exclusionAttribute(_ url: URL) -> String? {
        let size = getxattr(url.path, attribute, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard getxattr(url.path, attribute, &bytes, size, 0, 0) == size else { return nil }
        let data = Data(bytes)
        if let value = try? PropertyListSerialization.propertyList(from: data, format: nil) as? String { return value }
        return String(decoding: data, as: UTF8.self)
    }

    /// True when the folder carries the attribute tmutil reads, with Time Machine's own value.
    static func isExcluded(_ url: URL) -> Bool { exclusionAttribute(url) == "com.apple.backupd" }

    /// `tmutil isexcluded <path>`, waited on for at most `seconds`. Nil when it did not answer in time (it is then stopped).
    static func tmutil(_ url: URL, seconds: Double = 10) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["isexcluded", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        guard (try? process.run()) != nil else { return nil }
        if done.wait(timeout: .now() + seconds) == .timedOut {
            process.terminate()
            _ = done.wait(timeout: .now() + 2)
            return nil
        }
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
