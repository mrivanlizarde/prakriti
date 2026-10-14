import Foundation
import SQLite3
import SwiftData
import XCTest
@testable import Prakriti

/// Opens a COPY of a real store with this build's schema, the check to run before `make install`
/// whenever the models change. The live store is never opened here: the make target copies it first.
///
///   cd ~/Code/prakriti/mac && make migrate-check
///
/// Skipped unless PRAKRITI_STORE_COPY names the copied store.
@MainActor
final class StoreMigrationTests: XCTestCase {
    func testACopyOfTheStoreOpensWithThisSchema() throws {
        guard let path = ProcessInfo.processInfo.environment["PRAKRITI_STORE_COPY"], !path.isEmpty else {
            throw XCTSkip("Needs a copy of a store. Run it with: cd ~/Code/prakriti/mac && make migrate-check")
        }
        let live = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Prakriti/Prakriti.store").path
        XCTAssertNotEqual(URL(fileURLWithPath: path).resolvingSymlinksInPath().path, live, "never the live store itself")
        // What the copy held BEFORE this build opened it, read straight from SQLite. Reason (12 Oct): this
        // check used to assert that every field arrived empty, which was only true until Ivan used the
        // app; once he approved two talks and removed a recording on 11 Oct, it failed for every later
        // part although the schema was fine. A migration check must hold on any real store: a field this
        // build ADDS arrives at its default, and everything the store already had comes through unchanged.
        let before = try RawStore(path: path)
        let container = try PrakritiStore.makeContainer(at: URL(fileURLWithPath: path))
        let context = container.mainContext
        let recordings = try context.fetch(FetchDescriptor<Recording>())
        let sources = try context.fetch(FetchDescriptor<Source>())
        let settings = try context.fetch(FetchDescriptor<OutputSetting>())
        let lines = try context.fetchCount(FetchDescriptor<LogEntry>())
        XCTAssertFalse(sources.isEmpty, "the copy has its folders")
        XCTAssertFalse(settings.isEmpty, "the copy has its output settings")

        // Nothing that was there is lost: every row comes through.
        XCTAssertEqual(recordings.count, before.count("ZRECORDING"), "every recording comes through")
        XCTAssertEqual(sources.count, before.count("ZSOURCE"), "every folder comes through")
        XCTAssertEqual(settings.count, before.count("ZOUTPUTSETTING"), "every output setting comes through")
        XCTAssertEqual(lines, before.count("ZLOGENTRY"), "every Activity line comes through")

        // Nothing Ivan set is changed: per recording (by its path), its status, kind, approval, Serenity mark,
        // what was written and the podcast-ready record read the same as SQLite stored them.
        let rawRecordings = before.rows("ZRECORDING", ["ZFILEPATH", "ZSTATUSRAW", "ZKINDRAW", "ZAPPROVEDAT", "ZHASSERENITY", "ZWRITTENJSON", "ZPODCASTREADYJSON", "ZEPISODENUMBER", "ZEPISODEDURATION"])
        let modelRecordings = recordings.map { r -> [String] in
            [r.filePath, r.statusRaw, r.kindRaw, r.approvedAt == nil ? "nil" : "set", r.hasSerenity ? "1" : "0",
             r.writtenJSON == nil ? "nil" : "set", r.podcastReadyJSON == nil ? "nil" : "set",
             r.episodeNumber.map(String.init) ?? "nil", r.episodeDuration == nil ? "nil" : "set"]
        }
        let rawShaped = rawRecordings.map { row -> [String] in
            [row[0] ?? "", row[1] ?? "", row[2] ?? "", row[3] == nil ? "nil" : "set", row[4] ?? "0",
             row[5] == nil ? "nil" : "set", row[6] == nil ? "nil" : "set", row[7] ?? "nil", row[8] == nil ? "nil" : "set"]
        }
        XCTAssertEqual(modelRecordings.map { $0.joined(separator: "|") }.sorted(), rawShaped.map { $0.joined(separator: "|") }.sorted(),
                       "every recording reads as SQLite stored it")
        // Every output setting keeps its switch: the upgrade turns nothing on and nothing off.
        let rawSwitches = before.rows("ZOUTPUTSETTING", ["ZKINDRAW", "ZISON"]).map { "\($0[0] ?? "")=\($0[1] ?? "0")" }.sorted()
        XCTAssertEqual(settings.map { "\($0.kindRaw)=\($0.isOn ? 1 : 0)" }.sorted(), rawSwitches, "no switch moves in the upgrade")

        // Fields this build adds to the store arrive at their defaults. Each block runs only when the copy did
        // not have the field yet (the upgrade that adds it); once a store has it, its values are Ivan's.
        let gates = [("ZRECORDING", "ZEPISODEDURATION"), ("ZRECORDING", "ZEPISODEPARTS"), ("ZRECORDING", "ZWRITTENJSON"), ("ZRECORDING", "ZPODCASTREADYJSON"),
                     ("ZOUTPUTSETTING", "ZNUMBERINGRAW"), ("ZRECORDING", "ZCHECKEDCLAIMS"), ("ZSOURCE", "ZFORGOTTENPATHS"),
                     ("ZRECORDING", "ZCAPTUREJSON"), ("ZRECORDING", "ZFACESJSON")]
        print("Fields this open adds, so checked at their defaults: \(gates.filter { !before.has($0.0, $0.1) }.map(\.1)); already in the store, so compared as stored: \(gates.filter { before.has($0.0, $0.1) }.map(\.1))")
        if !before.has("ZRECORDING", "ZEPISODEDURATION") {
            // Milestone 4: nothing made by the app yet.
            for recording in recordings {
                XCTAssertNil(recording.episodeDuration)
                XCTAssertEqual(recording.madeFiles, [])
            }
        }
        if !before.has("ZRECORDING", "ZEPISODEPARTS") {
            // Milestone 5: no edits, none waiting for Make Again, nothing approved, and a recording engine v0
            // made reads as one part, all of it.
            for recording in recordings {
                XCTAssertTrue(recording.edits.isEmpty)
                XCTAssertFalse(recording.editsPending)
                XCTAssertEqual(recording.episodeParts, [])
                XCTAssertNil(recording.approvedAt)
                XCTAssertEqual(recording.approvedFiles, [])
                if recording.fromEngineV0, recording.status == .readyForYourYes, let duration = recording.duration {
                    XCTAssertEqual(recording.episodeClock?.segments, [Mastering.Span(start: 0, end: duration)])
                    XCTAssertTrue(ApprovalCheck.check(recording, isBusy: false).speakersNotChecked, "not marked as a talk yet")
                }
            }
        }
        if !before.has("ZRECORDING", "ZWRITTENJSON") {
            // Milestone 6: nothing written, no problem recorded, and no folder starts writing on its own.
            for recording in recordings {
                XCTAssertNil(recording.writtenJSON)
                XCTAssertNil(recording.writingProblem)
            }
        }
        let writingOn = sources.filter { $0.setting(for: .titlesNotesChapters)?.isOn == true }.map(\.name)
        if !before.has("ZRECORDING", "ZPODCASTREADYJSON") {
            // The podcast-ready episode (10 Oct): its recording fields arrive empty.
            for recording in recordings {
                XCTAssertNil(recording.podcastReadyJSON)
                XCTAssertNil(recording.podcastReadyProblem)
                XCTAssertNil(recording.episodeNumber)
            }
        }
        // The launch adds any output kind a store lacks, switched OFF everywhere, and never touches one it has.
        let hadReady = before.rows("ZOUTPUTSETTING", ["ZKINDRAW"]).contains { $0[0] == OutputKind.podcastReady.rawValue }
        let readyBefore = Set(settings.filter { $0.kind == .podcastReady }.map(\.id))
        let added = try PrakritiStore.addMissingOutputKinds(context)
        let addedSettings = try context.fetch(FetchDescriptor<OutputSetting>()).filter { !Set(settings.map(\.id)).contains($0.id) }
        XCTAssertTrue(addedSettings.allSatisfy { !$0.isOn }, "an output kind added in the upgrade starts off")
        XCTAssertTrue(sources.allSatisfy { $0.setting(for: .podcastReady) != nil }, "every folder has the podcast-ready switch")
        let defaultReady = try context.fetch(FetchDescriptor<OutputSetting>()).filter { $0.kind == .podcastReady && $0.source == nil && $0.recording == nil }
        XCTAssertEqual(defaultReady.count, 1, "the Outputs screen has its settings")
        if !hadReady {
            XCTAssertEqual(defaultReady.first?.isOn, false)
            XCTAssertEqual(sources.filter { $0.setting(for: .podcastReady)?.isOn == true }.map(\.name), [], "a folder would start making podcast-ready episodes on its own")
        }
        let readyOn = sources.filter { $0.setting(for: .podcastReady)?.isOn == true }.map(\.name)
        print("Output kinds added to the copy: \(added.map(\.title)) (\(addedSettings.count) settings, all off); podcast-ready existed before: \(hadReady) (\(readyBefore.count) settings), on in \(readyOn.count) folders")
        // The episode text (11 Oct): numbering and the call to action arrive unset when the store lacks them.
        let all = try context.fetch(FetchDescriptor<OutputSetting>())
        if !before.has("ZOUTPUTSETTING", "ZNUMBERINGRAW") {
            XCTAssertTrue(all.allSatisfy { $0.numbering == .none && $0.callToAction.isEmpty }, "numbering and call to action arrive unset")
        }
        print("Numbering and call to action on \(all.count) output settings: \(Set(all.map(\.numberingRaw))), \(all.filter { !$0.callToAction.isEmpty }.count) with a call to action")
        // v2 part M3a: the ticked accuracy claims and the folders' removed files arrive empty when the store lacks them.
        if !before.has("ZRECORDING", "ZCHECKEDCLAIMS") {
            XCTAssertTrue(recordings.allSatisfy { $0.checkedClaims.isEmpty }, "no claim arrives ticked")
        }
        if !before.has("ZSOURCE", "ZFORGOTTENPATHS") {
            XCTAssertTrue(sources.allSatisfy { $0.forgottenPaths.isEmpty }, "no folder arrives passing over a file")
        }
        // v2 part M4b: no recording arrives with a capture check (an upgrade checks nothing by itself, PLAN rule 2.1.7).
        if !before.has("ZRECORDING", "ZCAPTUREJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.captureJSON == nil }, "no recording arrives with a capture check")
        }
        print("v2 part M4b: \(recordings.filter { $0.captureJSON != nil }.count) recordings with a capture check")
        // v2 part M6a: no recording arrives with faces looked for (an upgrade looks at nothing by itself, rule 2.1.7).
        if !before.has("ZRECORDING", "ZFACESJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.facesJSON == nil }, "no recording arrives with faces looked for")
        }
        print("v2 part M6a: \(recordings.filter { $0.facesJSON != nil }.count) recordings with faces looked for")
        // v2 part M6b: no recording arrives listened to or with anyone named, and no folder with a microphone named.
        if !before.has("ZRECORDING", "ZVOICESJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.voicesJSON == nil }, "no recording arrives with voices listened for")
        }
        if !before.has("ZRECORDING", "ZNAMESJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.namesJSON == nil && $0.names.isEmpty }, "no recording arrives with anyone named")
        }
        if !before.has("ZSOURCE", "ZMICROPHONESJSON") {
            XCTAssertTrue(sources.allSatisfy { $0.microphones.isEmpty }, "no folder arrives with a microphone named")
        }
        print("v2 part M6b: \(recordings.filter { $0.voicesJSON != nil }.count) recordings with voices, \(recordings.filter { $0.namesJSON != nil }.count) with names, \(sources.filter { $0.microphonesJSON != nil }.count) folders with microphones")
        // v2 part M6c: no recording arrives with choices made, names said aloud found, or choices applied (an upgrade
        // decides nothing by itself, rule 2.1.7). Added 13 Oct after the verifier measured this by hand and found no test.
        if !before.has("ZRECORDING", "ZCHOICESJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.choicesJSON == nil }, "no recording arrives with choices made")
        }
        if !before.has("ZRECORDING", "ZNAMESSAIDJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.namesSaidJSON == nil }, "no recording arrives with names said aloud found")
        }
        if !before.has("ZRECORDING", "ZPEOPLEAPPLIEDJSON") {
            XCTAssertTrue(recordings.allSatisfy { $0.peopleAppliedJSON == nil }, "no recording arrives with choices applied")
        }
        print("v2 part M6c: \(recordings.filter { $0.choicesJSON != nil }.count) recordings with choices, \(recordings.filter { $0.namesSaidJSON != nil }.count) with names said aloud, \(recordings.filter { $0.peopleAppliedJSON != nil }.count) with choices applied")
        // v2 part M7a: every named person arrives with no release, nothing to forget, not hidden, pinned or a favorite, and
        // able to appear (Ivan's 12 Oct note); an upgrade records no release by itself.
        let people = try context.fetch(FetchDescriptor<Person>())
        if !before.has("ZPERSON", "ZRELEASESIGNEDON") {
            XCTAssertTrue(people.allSatisfy { $0.releaseSignedOn == nil && !$0.hasRelease && $0.forgottenAt == nil && !$0.pinned && !$0.favorite
                && !$0.hiddenFromPeople && $0.mayAppear && $0.keyPhotoJSON == nil && $0.roleRaw.isEmpty }, "a person arrives with a release or a gallery choice")
        }
        // Part LOCK: a store from before it has no noRelease column; everyone arrives with a signed release on file.
        if !before.has("ZPERSON", "ZNORELEASE") {
            XCTAssertTrue(people.allSatisfy { !$0.noRelease }, "an upgrade marks nobody no release")
        }
        // Part TXGAP: a store from before it has no transcriptGaps column; every recording arrives with none listed.
        if !before.has("ZRECORDING", "ZTRANSCRIPTGAPS") {
            XCTAssertTrue(recordings.allSatisfy { $0.transcriptGaps.isEmpty }, "an upgrade lists no missing words")
        }
        // Part M8c: a store from before it has no planRestores column; every recording arrives with nothing restored.
        if !before.has("ZRECORDING", "ZPLANRESTORES") {
            XCTAssertTrue(recordings.allSatisfy { $0.planRestores.isEmpty }, "an upgrade restores nothing")
        }
        print("part M8c: \(recordings.filter { !$0.planRestores.isEmpty }.count) recordings with restores; the store had the column before: \(before.has("ZRECORDING", "ZPLANRESTORES"))")
        print("part TXGAP: \(recordings.filter { !$0.transcriptGaps.isEmpty }.count) recordings with missing words listed; the store had the column before: \(before.has("ZRECORDING", "ZTRANSCRIPTGAPS"))")
        print("part LOCK: \(people.filter(\.noRelease).count) of \(people.count) named people marked no release; the store had the column before: \(before.has("ZPERSON", "ZNORELEASE"))")
        print("v2 part M7a: \(people.count) named people, \(people.filter(\.hasRelease).count) with a release, \(people.filter(\.mayAppear).count) able to appear")
        print("v2 part M3a fields:\(recordings.filter { !$0.checkedClaims.isEmpty }.count) recordings with ticked claims, \(sources.filter { !$0.forgottenPaths.isEmpty }.count) folders with removed files (\(sources.map(\.forgottenPaths.count).reduce(0, +)) files)")
        print("Rows before and after: recordings \(before.count("ZRECORDING"))/\(recordings.count), folders \(before.count("ZSOURCE"))/\(sources.count), output settings \(before.count("ZOUTPUTSETTING"))/\(settings.count), Activity lines \(before.count("ZLOGENTRY"))/\(lines); approved \(recordings.filter { $0.approvedAt != nil }.count)")
        let ready = recordings.filter { $0.status == .readyForYourYes }
        print("Store copy opened: \(recordings.count) recordings (\(ready.count) ready: "
              + ready.map { "\($0.fileName) \($0.loudnessLUFS.map { String($0) } ?? "?") LUFS" }.joined(separator: ", ")
              + "), \(sources.count) folders (" + sources.map(\.name).joined(separator: ", ") + "), \(settings.count) output settings, \(lines) Activity lines; "
              + "titles switched on in \(writingOn.count) folders; \(recordings.filter { $0.writtenJSON != nil }.count) recordings with anything written")
    }
}

/// The copy as SQLite holds it, read before SwiftData opens it (read only; the file is the copy, never the
/// live store). Only what the migration check compares: tables' columns, row counts, a few columns per row.
private final class RawStore {
    private var db: OpaquePointer?

    init(path: String) throws {
        // immutable=1: the copy is in WAL mode, and a plain read-only open of a WAL file with no -shm beside it
        // fails at the first query (measured 12 Oct: every count read 0), so the file is read as it stands.
        let uri = "file:" + (path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path) + "?immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            throw NSError(domain: "RawStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open \(path)"])
        }
        // Read everything now, then close, so SwiftData opens the file alone.
        for table in ["ZRECORDING", "ZSOURCE", "ZOUTPUTSETTING", "ZLOGENTRY"] {
            columnsByTable[table] = Set(query("SELECT name FROM pragma_table_info('\(table)')").compactMap { $0[0] })
            countsByTable[table] = Int(query("SELECT count(*) FROM \(table)").first?[0] ?? "0") ?? 0
        }
        for (table, columns) in [("ZRECORDING", ["ZFILEPATH", "ZSTATUSRAW", "ZKINDRAW", "ZAPPROVEDAT", "ZHASSERENITY", "ZWRITTENJSON", "ZPODCASTREADYJSON", "ZEPISODENUMBER", "ZEPISODEDURATION"]),
                                 ("ZOUTPUTSETTING", ["ZKINDRAW", "ZISON"]), ("ZOUTPUTSETTING", ["ZKINDRAW"])] {
            let present = columns.map { columnsByTable[table]?.contains($0) == true ? $0 : "NULL" }
            rowsByKey["\(table):\(columns.joined(separator: ","))"] = query("SELECT \(present.joined(separator: ", ")) FROM \(table)")
        }
        sqlite3_close(db)
        db = nil
        // A read that silently returned nothing would make every comparison in the test meaningless.
        if let failure { throw NSError(domain: "RawStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read the copy: \(failure)"]) }
        if countsByTable["ZRECORDING"] == 0 && columnsByTable["ZRECORDING"]?.isEmpty != false {
            throw NSError(domain: "RawStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "The copy has no recordings table"])
        }
    }

    private var failure: String?
    private var columnsByTable: [String: Set<String>] = [:]
    private var countsByTable: [String: Int] = [:]
    private var rowsByKey: [String: [[String?]]] = [:]

    func has(_ table: String, _ column: String) -> Bool { columnsByTable[table]?.contains(column) == true }
    func count(_ table: String) -> Int { countsByTable[table] ?? 0 }
    func rows(_ table: String, _ columns: [String]) -> [[String?]] { rowsByKey["\(table):\(columns.joined(separator: ","))"] ?? [] }

    private func query(_ sql: String) -> [[String?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            failure = failure ?? String(cString: sqlite3_errmsg(db))
            return []
        }
        defer { sqlite3_finalize(statement) }
        var result: [[String?]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append((0..<sqlite3_column_count(statement)).map { index in
                sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : sqlite3_column_text(statement, index).map { String(cString: $0) }
            })
        }
        return result
    }
}
