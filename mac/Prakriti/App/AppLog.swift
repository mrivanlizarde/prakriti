import Foundation
import os
import Synchronization

/// The plain-text log: one file per day in ~/Library/Logs/Prakriti/ (Development/ in development
/// mode), one line per event. Also mirrored to the unified log under the app's bundle id.
/// Never in any log: secrets, student names, transcript text. Numbers and file names only.
final class AppLog: Sendable {
    private let directory: URL?
    private let lock = Mutex<Void>(())
    private let logger = Logger(subsystem: "studio.therowan.prakriti.app", category: "app")

    /// `directory` nil means the unified log only (tests and snapshots).
    init(directory: URL?) {
        self.directory = directory
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    var todayFile: URL? {
        directory?.appending(path: Self.dayStamp(Date()) + ".log")
    }

    func write(_ message: String) {
        logger.info("\(message, privacy: .public)")
        guard let file = todayFile else { return }
        let line = Self.timeStamp(Date()) + "  " + message + "\n"
        lock.withLock { _ in
            let data = Data(line.utf8)
            if let handle = try? FileHandle(forWritingTo: file) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: file)
            }
        }
    }

    /// Local time, sortable, matching engine v0's log.txt ("2026-10-10 11:46:40").
    private static func stamp(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: date)
    }

    private static func dayStamp(_ date: Date) -> String { stamp(date, "yyyy-MM-dd") }
    private static func timeStamp(_ date: Date) -> String { stamp(date, "yyyy-MM-dd HH:mm:ss") }
}
