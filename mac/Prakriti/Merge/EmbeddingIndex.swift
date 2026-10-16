import Foundation
import SQLite3

// The index of moments on this Mac (v2 part M12a, docs/v2/PLAN.md M12, design spec 3.8, research-edit-engine.md 3.5): every
// recording's transcript cut into windows of whole sentences, 5 to 45 s, each embedded by `text-embedding-nomic-embed-text-v1.5` in
// LM Studio (`LocalEmbeddings`, the only way `Merge/` reaches a model), and kept in its own SQLite file under the mode's Application
// Support (`Merge/moments.sqlite`). Text, never a face or a voice: the file holds times, word numbers and numbers for meaning, not
// the words themselves (they are read from the transcript when a moment is shown, so a moment is always the transcript's own words).
//
// Only spans where everyone seen or heard may be in a moment offered to another video are indexed (`MomentPeople`): the recording's
// people check ran (faces and voices both), and every face and voice in the span is set to Include for the video, and no named person
// in it is marked "no release". Ivan's decision of Mon 12 Oct (every participant signed a release) makes an unnamed person on Include
// no reason to leave a span out; someone Ivan set to Hide Face or Leave Out, or a person he marked "no release", always is. A span is
// checked again at every search against the choices of that moment, so a change made after indexing drops it the same way.

/// A stretch of whole sentences of one transcript, 5 to 45 s, on the original's clock.
struct MomentWindow: Codable, Equatable, Hashable, Sendable {
    var start: Double
    var end: Double
    /// The first and last word (`PlanWord.index`).
    var firstWord: Int
    var lastWord: Int

    var seconds: Double { max(0, end - start) }
    var key: String { "\(firstWord)-\(lastWord)" }
}

enum MomentWindows {
    /// Design spec 3.8: clips 5 to 45 s.
    static let shortest = 5.0
    static let longest = 45.0
    /// A window grows sentence by sentence until it is this long (a point made in a few sentences), never past `longest`.
    static let aim = 15.0

    /// The sentences of a transcript as runs of words.
    static func sentences(_ words: [PlanWord]) -> [ClosedRange<Int>] {
        var out: [ClosedRange<Int>] = []
        var i = 0
        while i < words.count {
            var j = i
            while j + 1 < words.count && words[j + 1].sentence == words[i].sentence { j += 1 }
            out.append(i...j)
            i = j + 1
        }
        return out
    }

    /// One window from every sentence: that sentence and the ones after it until the window is `aim` long, never over `longest`;
    /// kept only when it is 5 to 45 s. Every window starts on a sentence's first word and ends on a sentence's last.
    static func make(_ words: [PlanWord]) -> [MomentWindow] {
        let runs = sentences(words)
        var out: [MomentWindow] = []
        var seen = Set<String>()
        for i in runs.indices {
            let start = words[runs[i].lowerBound].start
            var j = i
            while words[runs[j].upperBound].end - start < aim, j + 1 < runs.count, words[runs[j + 1].upperBound].end - start <= longest {
                j += 1
            }
            let window = MomentWindow(start: start, end: words[runs[j].upperBound].end, firstWord: words[runs[i].lowerBound].index,
                                      lastWord: words[runs[j].upperBound].index)
            guard window.seconds >= shortest, window.seconds <= longest, seen.insert(window.key).inserted else { continue }
            out.append(window)
        }
        return out
    }

    /// The window's words as the transcript has them.
    static func text(_ window: MomentWindow, words: [PlanWord]) -> String {
        guard window.firstWord >= 0, window.lastWord < words.count, window.firstWord <= window.lastWord else { return "" }
        return PlanWords.text(words[window.firstWord...window.lastWord])
    }
}

/// Who is seen and heard in one recording, and when, and whether each may be in a moment offered to another video.
struct MomentPeople: Sendable {
    struct Presence: Sendable, Equatable {
        var start: Double
        var end: Double
        var key: PersonKey
    }

    /// The people check ran: both the face step and the voice step (PLAN review item 5).
    var checked: Bool
    var faces: [Presence] = []
    var voices: [Presence] = []
    /// Why each person who may not be in a moment may not, by `PersonKey.string`.
    var blocked: [String: String] = [:]

    /// A face's box is held this long either side of a sighting (`HidePlan.hold`), so the same margin is read here.
    static let margin = 0.5

    /// From the people file, the voice step's voices, Ivan's names (resolved), his choices for the video and who has a release.
    static func from(file: PeopleFile?, voices found: VoicesFound?, names: (faces: [Int: UUID], voices: [Int: UUID]), choices: PeopleChoices,
                     people: [NamedPerson]) -> MomentPeople {
        guard let file, file.steps.contains("faces"), file.steps.contains("voices"), found != nil else { return MomentPeople(checked: false) }
        let released = Dictionary(people.map { ($0.id, $0.released) }, uniquingKeysWith: { $0 && $1 })
        var result = MomentPeople(checked: true)
        func judge(_ key: PersonKey) {
            guard result.blocked[key.string] == nil else { return }
            let choice = choices.choice(key, for: .video)
            if choice != .include {
                result.blocked[key.string] = "someone in it is set to \(choice.title)"
            } else if case .named(let id) = key, released[id] == false {
                result.blocked[key.string] = "someone in it has no signed release on file"
            }
        }
        for track in file.tracks {
            let key = PersonKey.face(track.person ?? 0, names: names)
            result.faces.append(Presence(start: track.start - margin, end: track.end + margin, key: key))
            judge(key)
        }
        let byID = Dictionary((found?.voices ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for segment in file.voices?.voiceSegments ?? [] {
            let key = byID[segment.voice].map { PersonKey.voice($0, names: names) } ?? .voice(segment.voice)
            result.voices.append(Presence(start: segment.start, end: segment.end, key: key))
            judge(key)
        }
        return result
    }

    /// Why this span may not be offered, or nil when everyone seen or heard in it is included and released.
    func problem(start: Double, end: Double) -> String? {
        guard checked else { return "its people have not been checked" }
        for presence in faces + voices where presence.end > start && presence.start < end {
            if let reason = blocked[presence.key.string] { return reason }
        }
        return nil
    }
}

/// The index file. One connection, used by one search at a time (`AppModel.momentWork` runs them in turn).
final class MomentIndex: @unchecked Sendable {
    struct Stored: Equatable, Sendable {
        var recording: UUID
        var window: MomentWindow
        var vector: [Float]
    }

    struct Failure: Error, Equatable, Sendable {
        let reason: String
    }

    static let folderName = "Merge"
    static let fileName = "moments.sqlite"

    let url: URL
    private var db: OpaquePointer?

    static func url(support: URL) -> URL {
        support.appending(path: folderName, directoryHint: .isDirectory).appending(path: fileName)
    }

    init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let reason = db.map { String(cString: sqlite3_errmsg($0)) } ?? "no connection"
            sqlite3_close(db)
            db = nil
            throw Failure(reason: "The moments index could not be opened (\(reason)).")
        }
        try run("""
            CREATE TABLE IF NOT EXISTS recordings (id TEXT PRIMARY KEY, teacher TEXT NOT NULL, signature TEXT NOT NULL, model TEXT NOT NULL,
                indexed_at REAL NOT NULL, windows INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS windows (recording TEXT NOT NULL, start REAL NOT NULL, end REAL NOT NULL, first_word INTEGER NOT NULL,
                last_word INTEGER NOT NULL, vector BLOB NOT NULL);
            CREATE INDEX IF NOT EXISTS windows_recording ON windows (recording);
            """)
    }

    deinit { sqlite3_close(db) }

    private func run(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &message) == SQLITE_OK else {
            let reason = message.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(message)
            throw Failure(reason: "The moments index could not be written (\(reason)).")
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Failure(reason: "The moments index could not be read (\(String(cString: sqlite3_errmsg(db)))).")
        }
        return statement
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// What the index holds for one recording: its teacher, the signature it was made under and the model, or nil.
    func entry(_ recording: UUID) throws -> (teacher: UUID?, signature: String, model: String, windows: Int)? {
        let statement = try prepare("SELECT teacher, signature, model, windows FROM recordings WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, recording.uuidString, -1, Self.transient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return (UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))), String(cString: sqlite3_column_text(statement, 1)),
                String(cString: sqlite3_column_text(statement, 2)), Int(sqlite3_column_int64(statement, 3)))
    }

    /// Replaces one recording's windows, in one transaction.
    func replace(_ recording: UUID, teacher: UUID, signature: String, model: String, windows: [MomentWindow], vectors: [[Float]], at date: Date) throws {
        guard windows.count == vectors.count else { throw Failure(reason: "The numbers did not match the windows.") }
        try run("BEGIN IMMEDIATE")
        do {
            try delete(recording)
            let insert = try prepare("INSERT INTO windows (recording, start, end, first_word, last_word, vector) VALUES (?, ?, ?, ?, ?, ?)")
            defer { sqlite3_finalize(insert) }
            for (window, vector) in zip(windows, vectors) {
                sqlite3_reset(insert)
                sqlite3_bind_text(insert, 1, recording.uuidString, -1, Self.transient)
                sqlite3_bind_double(insert, 2, window.start)
                sqlite3_bind_double(insert, 3, window.end)
                sqlite3_bind_int64(insert, 4, Int64(window.firstWord))
                sqlite3_bind_int64(insert, 5, Int64(window.lastWord))
                _ = vector.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(insert, 6, bytes.baseAddress, Int32(bytes.count), Self.transient)
                }
                guard sqlite3_step(insert) == SQLITE_DONE else { throw Failure(reason: "A window could not be written (\(String(cString: sqlite3_errmsg(db)))).") }
            }
            let row = try prepare("INSERT INTO recordings (id, teacher, signature, model, indexed_at, windows) VALUES (?, ?, ?, ?, ?, ?)")
            defer { sqlite3_finalize(row) }
            sqlite3_bind_text(row, 1, recording.uuidString, -1, Self.transient)
            sqlite3_bind_text(row, 2, teacher.uuidString, -1, Self.transient)
            sqlite3_bind_text(row, 3, signature, -1, Self.transient)
            sqlite3_bind_text(row, 4, model, -1, Self.transient)
            sqlite3_bind_double(row, 5, date.timeIntervalSince1970)
            sqlite3_bind_int64(row, 6, Int64(windows.count))
            guard sqlite3_step(row) == SQLITE_DONE else { throw Failure(reason: "The recording could not be written (\(String(cString: sqlite3_errmsg(db)))).") }
            try run("COMMIT")
        } catch {
            try? run("ROLLBACK")
            throw error
        }
    }

    private func delete(_ recording: UUID) throws {
        for sql in ["DELETE FROM windows WHERE recording = ?", "DELETE FROM recordings WHERE id = ?"] {
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, recording.uuidString, -1, Self.transient)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw Failure(reason: "A recording could not be taken out of the index.") }
        }
    }

    /// Takes one recording out of the index (Remove from Library, or nothing of it may be offered any more).
    func remove(_ recording: UUID) throws {
        try delete(recording)
    }

    /// The windows of these recordings.
    func windows(of recordings: [UUID]) throws -> [Stored] {
        var out: [Stored] = []
        let statement = try prepare("SELECT start, end, first_word, last_word, vector FROM windows WHERE recording = ? ORDER BY start")
        defer { sqlite3_finalize(statement) }
        for recording in recordings {
            sqlite3_reset(statement)
            sqlite3_bind_text(statement, 1, recording.uuidString, -1, Self.transient)
            while sqlite3_step(statement) == SQLITE_ROW {
                let count = Int(sqlite3_column_bytes(statement, 4)) / MemoryLayout<Float>.size
                var vector = [Float](repeating: 0, count: count)
                if let blob = sqlite3_column_blob(statement, 4), count > 0 {
                    vector.withUnsafeMutableBytes { $0.copyMemory(from: UnsafeRawBufferPointer(start: blob, count: count * MemoryLayout<Float>.size)) }
                }
                out.append(Stored(recording: recording, window: MomentWindow(start: sqlite3_column_double(statement, 0), end: sqlite3_column_double(statement, 1),
                                                                          firstWord: Int(sqlite3_column_int64(statement, 2)),
                                                                          lastWord: Int(sqlite3_column_int64(statement, 3))), vector: vector))
            }
        }
        return out
    }

    /// Every recording in the index.
    func recordings() throws -> [UUID] {
        let statement = try prepare("SELECT id FROM recordings")
        defer { sqlite3_finalize(statement) }
        var out: [UUID] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) { out.append(id) }
        }
        return out
    }
}

extension MomentIndex {
    /// The signature a recording's windows are kept under: its transcript, the spans that may be offered, the model and the prefix.
    /// Any change, and the recording is embedded again at the next search.
    static func signature(transcriptSHA256: String, windows: [MomentWindow], model: String) -> String {
        let text = transcriptSHA256 + "|" + model + "|" + LocalEmbeddings.documentPrefix + "|" + windows.map(\.key).joined(separator: ",")
        return PlanWords.sha256(Data(text.utf8))
    }
}
