import AppKit
import Foundation
import XCTest
@testable import Prakriti

/// The standing rules, checked on every test run: paths, dates, the status line, no em dashes,
/// and Ivan's type floor.
@MainActor
final class RulesTests: XCTestCase {
    // MARK: Paths

    func testDevelopmentStaysInsideItsOwnFolders() {
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        let dev = AppPaths(mode: .development, home: home)
        XCTAssertEqual(dev.drop.path, "/Users/someone/Prakriti/Dev/Drop")
        XCTAssertEqual(dev.outputs.path, "/Users/someone/Prakriti/Dev/Outputs")
        XCTAssertEqual(dev.approved.path, "/Users/someone/Prakriti/Dev/Approved")
        XCTAssertEqual(dev.store.path, "/Users/someone/Library/Application Support/Prakriti/Development/Prakriti.store")
        XCTAssertEqual(dev.logs.path, "/Users/someone/Library/Logs/Prakriti/Development")

        // Engine v0 watches ~/Prakriti/Drop (and three levels below it) and the studio folder.
        // Nothing the app creates in development may sit inside either.
        let v0Watched = [home.appending(path: "Prakriti/Drop").path + "/", dev.studioRecordings.path]
        for folder in dev.foldersToCreate {
            for watched in v0Watched {
                XCTAssertFalse(folder.path.hasPrefix(watched), "\(folder.path) is inside a folder engine v0 watches")
            }
        }

        let live = AppPaths(mode: .live, home: home)
        XCTAssertEqual(live.drop.path, "/Users/someone/Prakriti/Drop")
        XCTAssertEqual(live.outputs.path, "/Users/someone/Prakriti/Outputs")
        XCTAssertEqual(live.approved.path, "/Users/someone/Prakriti/Approved", "Approve copies into ~/Prakriti/Approved/<name> in the live app")
        XCTAssertEqual(live.store.path, "/Users/someone/Library/Application Support/Prakriti/Prakriti.store")
    }

    func testTheStudioFolderNameKeepsItsTrailingSpace() {
        let paths = AppPaths(mode: .live, home: URL(fileURLWithPath: "/Users/someone", isDirectory: true))
        XCTAssertTrue(paths.studioRecordings.path.hasSuffix("Studio Recordings "), "the folder's real name ends in a space")
    }

    func testOutputsNeverGoIntoTheSharedFolderOrDocuments() {
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        let paths = AppPaths(mode: .live, home: home)
        XCTAssertFalse(paths.isSafeOutputLocation(paths.studioRecordings.appending(path: "2026-09-13/out")))
        XCTAssertFalse(paths.isSafeOutputLocation(home.appending(path: "Documents/anything")))
        XCTAssertFalse(paths.isSafeOutputLocation(home.appending(path: "Documents")))
        XCTAssertTrue(paths.isSafeOutputLocation(paths.outputs.appending(path: "2026-09-13 18-25-44")))
        XCTAssertTrue(paths.isSafeOutputLocation(paths.approved))
        XCTAssertTrue(paths.isSafeOutputLocation(home.appending(path: "DocumentsArchive")), "a sibling that only starts with the same letters is fine")
    }

    // MARK: Dates and numbers

    func testWeekdaysAreComputed() {
        // Checked with date(1): date -j -f %Y-%m-%d 2026-09-13 +%a
        XCTAssertEqual(Format.dayLabel(Fixtures.date(2026, 9, 6)), "Sun 6 Sep")
        XCTAssertEqual(Format.dayLabel(Fixtures.date(2026, 9, 13)), "Sun 13 Sep")
        XCTAssertEqual(Format.dayLabel(Fixtures.date(2026, 9, 14)), "Mon 14 Sep")
        XCTAssertEqual(Format.dayLabel(Fixtures.date(2026, 10, 10)), "Sat 10 Oct")
        XCTAssertEqual(Format.dayLabel(Fixtures.date(2026, 10, 23)), "Fri 23 Oct")
        XCTAssertEqual(Format.longDay(Fixtures.date(2026, 10, 10)), "Saturday 10 October")
        XCTAssertEqual(Format.clock(Fixtures.date(2026, 9, 13, 18, 25)), "6:25 pm")
    }

    func testLengthsAndTimecodes() {
        XCTAssertEqual(Format.length(45), "45 s")
        XCTAssertEqual(Format.length(90), "1 min 30 s")
        XCTAssertEqual(Format.length(947.78), "15 min 48 s")
        XCTAssertEqual(Format.length(3702.27), "1 hr 2 min")
        XCTAssertEqual(Format.length(3600), "1 hr")
        XCTAssertEqual(Format.timecode(947), "15:47")
        XCTAssertEqual(Format.timecode(947.78), "15:48")
        XCTAssertEqual(Format.timecode(3702.27), "1:01:42")
        XCTAssertEqual(Format.lufs(-16.8), "-16.8 LUFS")
        XCTAssertEqual(Format.size(730_464_600), "730 MB")
        XCTAssertEqual(Format.size(2_858_813_029), "2.86 GB")
        XCTAssertEqual(Format.number(2948), "2,948")
    }

    // MARK: The status line

    func testStatusLineSaysWhatIsHappening() {
        let notWatching = StatusSummary.make(isWatching: false, isPaused: false, folderNames: ["Test drop folder"], needsYou: 0, problems: 0, working: nil)
        XCTAssertEqual(notWatching.line, AppMode.switchedOver ? "Not watching. New recordings wait until Prakriti watches again."
                                                              : "Not watching yet. The old engine still handles new recordings.")
        XCTAssertEqual(notWatching.icon, .notWatching)

        let paused = StatusSummary.make(isWatching: true, isPaused: true, folderNames: ["A"], needsYou: 3, problems: 1, working: ("Sun 6 Sep", "Transcript"))
        XCTAssertEqual(paused.icon, .paused, "paused wins over everything")

        let working = StatusSummary.make(isWatching: true, isPaused: false, folderNames: ["A"], needsYou: 1, problems: 0,
                                         working: ("Sun 6 Sep", "Making the episode audio"))
        XCTAssertEqual(working.line, "Working on Sun 6 Sep: making the episode audio")
        XCTAssertFalse(working.line.localizedCaseInsensitiveContains("processing"))

        let waiting = StatusSummary.make(isWatching: true, isPaused: false, folderNames: ["Studio Recordings", "Drop folder"],
                                         needsYou: 2, problems: 0, working: nil)
        XCTAssertEqual(waiting.line, "Watching Studio Recordings and Drop folder. 2 recordings need you.")
        XCTAssertEqual(waiting.icon, .waitingForYou)

        let problem = StatusSummary.make(isWatching: true, isPaused: false, folderNames: ["A"], needsYou: 1, problems: 1, working: nil)
        XCTAssertEqual(problem.line, "Watching A. 1 recording needs you.")
        XCTAssertEqual(problem.icon, .problem)

        let idle = StatusSummary.make(isWatching: true, isPaused: false, folderNames: ["A", "B", "C"], needsYou: 0, problems: 0, working: nil)
        XCTAssertEqual(idle.line, "Watching 3 folders. Nothing waiting.")
        XCTAssertEqual(idle.icon, .idle)

        let blocked = StatusSummary.make(isWatching: true, isPaused: false, folderNames: ["Studio Recordings", "Drop folder"],
                                         blockedFolders: ["Studio Recordings"], needsYou: 0, problems: 0, working: nil)
        XCTAssertEqual(blocked.line, "Watching Studio Recordings and Drop folder. Studio Recordings cannot be read yet: macOS needs your OK. See Sources.")
        XCTAssertEqual(blocked.icon, .problem)

        XCTAssertEqual(Set([StatusSummary.Icon.idle, .notWatching, .working, .waitingForYou, .problem, .paused].map(\.rawValue)).count, 6,
                       "each menu bar state has its own shape")
    }

    // MARK: The menu bar mark (v2 part M1, docs/v2/icons/README.md)

    /// Six states, six glyphs: distinct names, each loading from the app's own asset catalog as an
    /// 18 by 18 pt template image (black on clear, so macOS colors it for a light or dark menu bar),
    /// and each drawing a different shape. The second working frame loads the same way.
    func testEveryMenuBarStateHasItsOwnGlyph() throws {
        let states = StatusSummary.Icon.allCases
        XCTAssertEqual(states.count, 6)
        let names = states.map(\.menuBarAsset)
        XCTAssertEqual(Set(names).count, 6, "six distinct menu bar glyph names: \(names)")
        XCTAssertEqual(StatusSummary.Icon.working.menuBarAsset, "prakriti-menubar-working-1")

        var drawings: [String: [UInt8]] = [:]
        for name in names + [StatusSummary.Icon.workingFrames[1]] {
            let image = try XCTUnwrap(NSImage(named: name), "\(name) is not in the app's asset catalog")
            XCTAssertEqual(image.size, NSSize(width: 18, height: 18), "\(name) is drawn for an 18 pt square")
            XCTAssertTrue(image.isTemplate, "\(name) must be a template image, or it stays black on a dark menu bar")
            drawings[name] = Self.alphaMask(image, pixels: 36)
        }
        // The shapes themselves differ, not only their names: every pair differs in at least 20 of
        // the 1,296 pixels of a 2x drawing (a dimmed half or a badge changes far more than that).
        let keys = drawings.keys.sorted()
        for (i, a) in keys.enumerated() {
            XCTAssertGreaterThan(drawings[a]!.filter { $0 > 127 }.count, 100, "\(a) draws something")
            for b in keys[(i + 1)...] {
                let differing = zip(drawings[a]!, drawings[b]!).filter { abs(Int($0) - Int($1)) > 127 }.count
                XCTAssertGreaterThanOrEqual(differing, 20, "\(a) and \(b) look the same (\(differing) px differ)")
            }
        }
    }

    /// The image's coverage (alpha) at `pixels` by `pixels`, one byte per pixel.
    private static func alphaMask(_ image: NSImage, pixels: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: pixels * pixels)
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: pixels, height: pixels, bitsPerComponent: 8,
                                          bytesPerRow: pixels, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
            NSGraphicsContext.restoreGraphicsState()
        }
        return bytes
    }

    /// The working frames turn every 0.7 s while work runs, there is no timer while nothing works,
    /// and Reduce Motion holds the first frame still. Driven on a clock the test moves by hand.
    func testWorkingTickerTurnsOnlyWhileWorking() {
        let clock = ManualTickerClock()
        let ticker = WorkingTicker(clock: clock, reduceMotion: { false }, reduceMotionChanges: nil)

        // Idle: nothing scheduled, the first frame.
        XCTAssertNil(ticker.timer, "no timer while idle")
        XCTAssertTrue(clock.scheduled.isEmpty)
        XCTAssertEqual(ticker.frame, "prakriti-menubar-working-1")

        // Working: one timer, every 0.7 s, flipping exactly on the interval.
        ticker.setWorking(true)
        XCTAssertNotNil(ticker.timer)
        XCTAssertEqual(clock.scheduled.count, 1)
        XCTAssertEqual(clock.scheduled.first?.interval, 0.7)
        var flips: [TimeInterval] = []
        var last = ticker.odd
        for step in 1...100 {   // 0.07 s steps over 7 s
            clock.advance(to: Double(step) * 0.07)
            if ticker.odd != last { flips.append(clock.now); last = ticker.odd }
        }
        XCTAssertEqual(flips.count, 10, "ten flips in 7 s: \(flips)")
        for (n, time) in flips.enumerated() {
            XCTAssertEqual(time, Double(n + 1) * 0.7, accuracy: 1e-9, "flip \(n + 1) on the interval")
        }
        XCTAssertFalse(ticker.odd, "an even number of flips: back on the first frame")
        clock.advance(to: 7.35)
        XCTAssertFalse(ticker.odd, "no flip between intervals")
        clock.advance(to: 7.7)
        XCTAssertTrue(ticker.odd)
        XCTAssertEqual(ticker.frame, "prakriti-menubar-working-2")

        // Working again while working: still one timer.
        ticker.setWorking(true)
        XCTAssertEqual(clock.scheduled.count, 1, "never two timers")

        // Work ends: the timer is cancelled and gone, the first frame comes back, and time moving on
        // flips nothing.
        let scheduled = clock.scheduled[0]
        ticker.setWorking(false)
        XCTAssertNil(ticker.timer, "no timer once nothing works")
        XCTAssertTrue(scheduled.cancelled)
        XCTAssertFalse(ticker.odd)
        clock.advance(to: 20)
        XCTAssertFalse(ticker.odd)
    }

    func testWorkingTickerNeverStartsWithReduceMotion() {
        let clock = ManualTickerClock()
        let reduceMotion = Box(true)
        let ticker = WorkingTicker(clock: clock, reduceMotion: { reduceMotion.value }, reduceMotionChanges: nil)

        ticker.setWorking(true)
        XCTAssertNil(ticker.timer, "Reduce Motion on: no timer")
        XCTAssertTrue(clock.scheduled.isEmpty, "Reduce Motion on: nothing ever scheduled")
        clock.advance(to: 10)
        XCTAssertEqual(ticker.frame, "prakriti-menubar-working-1", "the first frame, held still")

        // Turned off while working (macOS posts a change): the frames start turning.
        reduceMotion.value = false
        ticker.refresh()
        XCTAssertNotNil(ticker.timer)
        clock.advance(to: 10.7)
        XCTAssertTrue(ticker.odd)

        // Turned on again while working: stopped at once, on the first frame.
        reduceMotion.value = true
        ticker.refresh()
        XCTAssertNil(ticker.timer)
        XCTAssertTrue(clock.scheduled[0].cancelled)
        XCTAssertEqual(ticker.frame, "prakriti-menubar-working-1")
    }

    /// The app's own clock schedules a real timer and stops it: proved with a 0.05 s interval on the
    /// main run loop.
    func testSystemTickerClockTicksAndStops() {
        let clock = SystemTickerClock()
        let ticks = Box(0)
        let ticked = expectation(description: "three ticks")
        let timer = clock.every(0.05) {
            ticks.value += 1
            if ticks.value == 3 { ticked.fulfill() }
        }
        wait(for: [ticked], timeout: 2)
        timer.cancel()
        let after = ticks.value
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        XCTAssertEqual(ticks.value, after, "no tick after cancel")
    }

    // MARK: Copy and type rules, read from the source files

    private var appSourceFiles: [URL] {
        let appFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Prakriti")
        let enumerator = FileManager.default.enumerator(at: appFolder, includingPropertiesForKeys: nil)
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if ["swift", "plist"].contains(url.pathExtension) { files.append(url) }
        }
        return files
    }

    func testTheSourcesAreFound() {
        XCTAssertGreaterThan(appSourceFiles.count, 10, "the rule checks below must actually read the app's files")
    }

    func testNoEmDashesAnywhereInTheApp() throws {
        for file in appSourceFiles {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in text.components(separatedBy: "\n").enumerated() where line.contains("\u{2014}") {
                XCTFail("Em dash in \(file.lastPathComponent) line \(number + 1): \(line)")
            }
        }
    }

    func testNoTooltips() throws {
        // Tooltips draw at the system tooltip size, under Ivan's 12 pt floor. Measured 10 Oct.
        XCTAssertLessThan(NSFont.toolTipsFont(ofSize: 0).pointSize, 12, "if tooltips ever reach 12 pt, this rule can go")
        for file in appSourceFiles where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in text.components(separatedBy: "\n").enumerated() where line.contains(".help(") || line.contains("toolTip") {
                XCTFail("Tooltip in \(file.lastPathComponent) line \(number + 1): name the control in its label instead")
            }
        }
    }

    func testModelNamesReadAsPeopleSayThem() {
        XCTAssertEqual(Format.modelName("qwen/qwen3.8-27b"), "Qwen3.8-27B")
        XCTAssertEqual(Format.modelName("google/gemma-3-27b"), "Gemma-3-27B")
        XCTAssertEqual(Format.modelName("mistral-small"), "Mistral-small")
        XCTAssertEqual(Format.modelName(""), "")
    }

    func testNoProcessingEllipsisOrBannedWords() throws {
        for file in appSourceFiles where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in text.components(separatedBy: "\n").enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") { continue }
                for banned in ["\"Processing", "Oops", "We're ", "we're "] where line.contains(banned) {
                    XCTFail("\(banned) in \(file.lastPathComponent) line \(number + 1)")
                }
            }
        }
    }

    func testEveryFontComesFromTheTypeScale() throws {
        let builtInStyles = [".largeTitle", ".title", ".title2", ".title3", ".headline", ".subheadline", ".body",
                             ".callout", ".footnote", ".caption", ".caption2"]
        for file in appSourceFiles where file.pathExtension == "swift" && file.lastPathComponent != "AppFont.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in text.components(separatedBy: "\n").enumerated() {
                let where_ = "\(file.lastPathComponent) line \(number + 1)"
                XCTAssertFalse(line.contains(".system(size:"), "Font sizes live in AppFont only: \(where_)")
                for style in builtInStyles where line.contains(".font(\(style))") || line.contains(".font(Font\(style))") {
                    XCTFail("Built-in text style \(style) renders at or under 13 pt on macOS (some at 10 pt): \(where_)")
                }
                XCTAssertFalse(line.contains(".badge("), "Sidebar badges draw under 12 pt: \(where_)")
                XCTAssertFalse(line.contains(".controlSize(.small)") || line.contains(".controlSize(.mini)"), "Small controls draw under 12 pt: \(where_)")
            }
        }
        XCTAssertTrue(AppFont.sizes.allSatisfy { $0 >= 12 }, "nothing under 12 pt")
        XCTAssertTrue(AppFont.sizes.contains(17), "body text is 17 pt")
    }
}

/// A value a main-actor closure can read and the test can change.
@MainActor
private final class Box<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

/// A clock the test moves by hand: each scheduled timer fires once for every whole interval passed.
@MainActor
final class ManualTickerClock: TickerClock {
    final class Scheduled: TickerTimer {
        let interval: TimeInterval
        var next: TimeInterval
        let tick: @MainActor @Sendable () -> Void
        private(set) var cancelled = false
        init(interval: TimeInterval, next: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void) {
            self.interval = interval
            self.next = next
            self.tick = tick
        }
        func cancel() { cancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private(set) var scheduled: [Scheduled] = []

    func every(_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Void) -> any TickerTimer {
        let timer = Scheduled(interval: interval, next: now + interval, tick: tick)
        scheduled.append(timer)
        return timer
    }

    func advance(to time: TimeInterval) {
        while let due = scheduled.filter({ !$0.cancelled && $0.next <= time + 1e-9 }).min(by: { $0.next < $1.next }) {
            now = due.next
            due.next += due.interval
            due.tick()
        }
        now = time
    }
}
