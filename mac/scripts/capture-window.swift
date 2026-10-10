// Captures the REAL Prakriti window, every sidebar screen in light and in dark, and checks what the
// bitmap snapshots can only imitate: the selected sidebar row as macOS really draws it (Liquid Glass
// and the accent-colored selection) must show its icon and its label. Reason: on 10 Oct the selected
// row's icon was invisible in the real window (accent icon on an accent selection) while every
// snapshot looked fine. Last, it tries to add the Studio Recordings folder and checks that the
// development refusal alert appears.
//
//   cd ~/Code/prakriti/mac && make look
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift build/Build/Products/Debug/Prakriti.app ../screens/mac/latest/real
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --analyze some-capture.png
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --window build/Build/Products/Debug/Prakriti.app out.png
//
// The app opens with --sample-data: the same sample recordings as the snapshots, in memory only,
// so nothing is saved and Ivan's store is never opened. Each launch takes the screen's focus for a
// few seconds (the window must be frontmost for macOS to draw the selection in the accent color).
// Needs no Screen Recording permission on this Mac: `screencapture -l` captures one window.
import AppKit
import CoreGraphics
import Foundation

let screens = ["today", "recordings", "sources", "outputs", "models", "activity", "settings"]
let appearances = ["light", "dark"]

struct RowCheck {
    let found: Bool
    let rowPixels: CGRect
    let fill: (r: Int, g: Int, b: Int)
    let iconPixels: Int
    let iconColor: (r: Int, g: Int, b: Int)
    let textPixels: Int
    var passes: Bool { found && iconPixels >= 150 && textPixels >= 150 }
    var isAccent: Bool { max(fill.r, fill.g, fill.b) - min(fill.r, fill.g, fill.b) > 90 }
}

/// Finds the selected sidebar row (the largest accent-colored area in the sidebar column), then
/// counts the pixels in its icon slot and its text slot that stand out from the fill.
func analyze(_ url: URL) -> RowCheck? {
    guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: url)) ?? Data()),
          let srgb = rep.converting(to: .sRGB, renderingIntent: .default) else { return nil }
    let w = srgb.pixelsWide, h = srgb.pixelsHigh
    func px(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        var p = [Int](repeating: 0, count: 4)
        srgb.getPixel(&p, atX: x, y: y)
        return (p[0], p[1], p[2])
    }
    func distance(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Int {
        abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2)
    }
    // The sidebar column, below the title bar: the sidebar is 220 of the window's 1180 points, so
    // the first 17% of the width stays inside it (the page beside it is a different color).
    let columnWidth = w * 17 / 100
    let top = h / 14
    func key(_ c: (Int, Int, Int)) -> Int { (c.0 / 8) << 10 | (c.1 / 8) << 5 | (c.2 / 8) }
    func color(_ k: Int) -> (Int, Int, Int) { ((k >> 10 & 31) * 8 + 4, (k >> 5 & 31) * 8 + 4, (k & 31) * 8 + 4) }
    var counts: [Int: Int] = [:]
    for y in stride(from: top, to: h, by: 2) {
        for x in stride(from: 0, to: columnWidth, by: 2) { counts[key(px(x, y)), default: 0] += 1 }
    }
    // The sidebar's background is its most common color; the selection is the most common color
    // that is clearly not the background. macOS draws it in the accent color while the sidebar has
    // the focus, and in grey once the page beside it takes the focus (Recordings and Activity do).
    let ranked = counts.sorted { $0.value > $1.value }
    guard let background = ranked.first.map({ color($0.key) }),
          let (fillKey, n) = ranked.first(where: { distance(color($0.key), background) > 24 }).map({ ($0.key, $0.value) }), n > 400 else {
        return RowCheck(found: false, rowPixels: .zero, fill: (0, 0, 0), iconPixels: 0, iconColor: (0, 0, 0), textPixels: 0)
    }
    let fill = color(fillKey)
    // The row is the band of lines where more than 120 px are the fill color. Icons in the other
    // rows can share the accent color, but none is wider than about 50 px.
    var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
    for y in top..<h {
        var count = 0, first = -1, last = -1
        for x in 0..<columnWidth where distance(px(x, y), fill) < 30 {
            count += 1
            if first < 0 { first = x }
            last = x
        }
        guard count > 120 else {
            if minY != Int.max { break }   // the band has ended
            continue
        }
        minY = min(minY, y); maxY = y
        minX = min(minX, first); maxX = max(maxX, last)
    }
    guard minY != Int.max else {
        return RowCheck(found: false, rowPixels: .zero, fill: fill, iconPixels: 0, iconColor: (0, 0, 0), textPixels: 0)
    }
    let row = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    // Icon slot: the first 16% of the row's width; text slot: from 20% to 60%. Both inset from the
    // row's rounded top and bottom.
    let y0 = minY + Int(row.height * 0.2), y1 = maxY - Int(row.height * 0.2)
    var icon = 0, iconSum = (0, 0, 0), text = 0
    for y in y0...y1 {
        for x in minX..<(minX + Int(row.width * 0.16)) {
            let c = px(x, y)
            if distance(c, fill) > 90 { icon += 1; iconSum = (iconSum.0 + c.0, iconSum.1 + c.1, iconSum.2 + c.2) }
        }
        for x in (minX + Int(row.width * 0.2))..<(minX + Int(row.width * 0.6)) where distance(px(x, y), fill) > 90 {
            text += 1
        }
    }
    let iconColor = icon > 0 ? (iconSum.0 / icon, iconSum.1 / icon, iconSum.2 / icon) : (0, 0, 0)
    return RowCheck(found: row.height > 30 && row.height < 200 && row.width > 150, rowPixels: row, fill: fill,
                    iconPixels: icon, iconColor: iconColor, textPixels: text)
}

func describe(_ name: String, _ check: RowCheck?) -> Bool {
    guard let check else { print("FAIL  \(name): could not read the picture"); return false }
    guard check.found else {
        print("FAIL  \(name): no selected row found in the sidebar")
        return false
    }
    let verdict = check.passes ? "PASS" : "FAIL"
    let chroma = max(check.fill.r, check.fill.g, check.fill.b) - min(check.fill.r, check.fill.g, check.fill.b)
    let kind = chroma > 90 ? "accent" : "grey, the page has the focus"
    print("\(verdict)  \(name): selected row \(Int(check.rowPixels.width))x\(Int(check.rowPixels.height)) px, fill rgb\(check.fill) (\(kind)), "
          + "icon \(check.iconPixels) px (rgb\(check.iconColor)), text \(check.textPixels) px")
    return check.passes
}

@discardableResult
func run(_ path: String, _ args: [String]) -> (Int32, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    try? p.run()
    p.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (p.terminationStatus, out)
}

/// The running app's process ids, from pgrep. Not NSRunningApplication: without a run loop its list
/// goes stale in a script and keeps returning the first instance after it quits.
func pids(of app: URL) -> [pid_t] {
    let (_, out) = run("/usr/bin/pgrep", ["-f", app.appending(path: "Contents/MacOS/Prakriti").path])
    return out.split(separator: "\n").compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
}

func quitAll(_ app: URL) {
    for pid in pids(of: app) { kill(pid, SIGTERM) }
    let deadline = Date().addingTimeInterval(8)
    while !pids(of: app).isEmpty && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
    for pid in pids(of: app) { kill(pid, SIGKILL) }
    Thread.sleep(forTimeInterval: 0.5)
}

/// The process's ordinary windows (layer 0), leaving out the menu bar item's strips.
func layerZeroWindows(pid: pid_t) -> [(CGWindowID, CGRect)] {
    let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
    return list.compactMap { info in
        guard (info[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid,
              (info[kCGWindowLayer as String] as? Int) == 0,
              let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict), bounds.height > 100,
              let number = info[kCGWindowNumber as String] as? Int else { return nil }
        return (CGWindowID(number), bounds)
    }
}

/// The app's main window: wider than any alert.
func mainWindowID(pid: pid_t) -> (CGWindowID, CGRect)? {
    layerZeroWindows(pid: pid).first { $0.1.width > 600 }
}

// MARK: Main

var args = Array(CommandLine.arguments.dropFirst())
// Captures the window of an app that is already running, as it is (Ivan's real store, not sample
// data): used by scripts/process-in-app.sh after the real app has processed a file.
if args.first == "--window", args.count == 3 {
    let app = URL(fileURLWithPath: args[1]).standardizedFileURL
    let png = URL(fileURLWithPath: args[2]).standardizedFileURL
    try? FileManager.default.createDirectory(at: png.deletingLastPathComponent(), withIntermediateDirectories: true)
    var found: (CGWindowID, CGRect)?
    var pid: pid_t = 0
    let deadline = Date().addingTimeInterval(15)
    while found == nil && Date() < deadline {
        if let first = pids(of: app).first { pid = first; found = mainWindowID(pid: pid) }
        if found == nil { Thread.sleep(forTimeInterval: 0.3) }
    }
    guard let (windowID, _) = found else { print("FAIL  no Prakriti window to capture"); exit(1) }
    NSRunningApplication(processIdentifier: pid)?.activate()
    Thread.sleep(forTimeInterval: 2.0)
    let (status, text) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(windowID), png.path])
    guard status == 0 else { print("FAIL  screencapture said \(text)"); exit(1) }
    let size = NSImageRep(contentsOf: png).map { "\($0.pixelsWide)x\($0.pixelsHigh) px" } ?? "unreadable"
    print("      saved \(png.path), \(size)")
    exit(0)
}
if args.first == "--analyze" {
    let ok = args.dropFirst().map { describe(($0 as NSString).lastPathComponent, analyze(URL(fileURLWithPath: $0))) }
    exit(ok.allSatisfy { $0 } ? 0 : 1)
}
guard args.count == 2 else {
    print("usage: swift scripts/capture-window.swift <Prakriti.app> <output folder>")
    print("       swift scripts/capture-window.swift --analyze <png>...")
    exit(2)
}
let app = URL(fileURLWithPath: args[0]).standardizedFileURL
let out = URL(fileURLWithPath: args[1]).standardizedFileURL
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

quitAll(app)
var failures = 0
var index = 0
for appearance in appearances {
    for screen in screens {
        index += 1
        let name = String(format: "%02d-%@-%@", screens.firstIndex(of: screen)! + 1, screen, appearance)
        // One word per flag: a value given as its own word reads to macOS as a file to open, and
        // then the app does not open its window.
        run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--show=" + screen, "--appearance=" + appearance])
        var found: (CGWindowID, CGRect)?
        var pid: pid_t = 0
        let deadline = Date().addingTimeInterval(15)
        while found == nil && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            if let first = pids(of: app).first {
                pid = first
                found = mainWindowID(pid: pid)
            }
        }
        guard let (windowID, _) = found else {
            print("FAIL  \(name): the window did not appear within 15 s")
            failures += 1
            quitAll(app)
            continue
        }
        // Let SwiftUI lay out and the glass settle, and make sure the window is frontmost.
        NSRunningApplication(processIdentifier: pid)?.activate()
        Thread.sleep(forTimeInterval: 2.0)
        let png = out.appending(path: name + ".png")
        let (status, text) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(windowID), png.path])
        if status != 0 {
            print("FAIL  \(name): screencapture said \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
            failures += 1
        } else {
            let size = NSImageRep(contentsOf: png).map { "\($0.pixelsWide)x\($0.pixelsHigh) px" } ?? "unreadable"
            print("      \(name): saved \(png.lastPathComponent), \(size)")
            let check = analyze(png)
            if !describe(name, check) { failures += 1 }
            // Today opens with the sidebar focused, so its selection must be the accent color: that
            // is the state that hid the icon on 10 Oct. Grey there means the window was not frontmost
            // and the check proved nothing.
            if screen == "today" && check?.isAccent != true {
                print("FAIL  \(name): the selection is not in the accent color, so the window was not frontmost. Run it again without touching the Mac.")
                failures += 1
            }
        }
        quitAll(app)
    }
}
// The development refusal, seen in the real window: the app tries to add the Studio Recordings
// folder (in memory, through the same path Add Folder takes) and must show its alert.
for appearance in appearances {
    let name = "08-refusal-\(appearance)"
    let studio = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/Design Work/Galindo x Lizarde/Studio Recordings "
    // --development: the refusal belongs to a test copy. The live Prakriti owns the studio folder.
    run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--development", "--show=sources", "--appearance=" + appearance, "--add-folder=" + studio])
    var windows: [(CGWindowID, CGRect)] = []
    let deadline = Date().addingTimeInterval(15)
    while windows.count < 2 && Date() < deadline {
        Thread.sleep(forTimeInterval: 0.3)
        if let pid = pids(of: app).first { windows = layerZeroWindows(pid: pid) }
    }
    if let pid = pids(of: app).first { NSRunningApplication(processIdentifier: pid)?.activate() }
    Thread.sleep(forTimeInterval: 1.5)
    let main = windows.max { $0.1.width < $1.1.width }
    let alert = windows.first { $0.1.width < 600 }
    if let main, alert != nil {
        let png = out.appending(path: name + ".png")
        run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(main.0), png.path])
        print("PASS  \(name): the refusal alert opened (\(Int(alert!.1.width))x\(Int(alert!.1.height)) pt), saved \(png.lastPathComponent)")
    } else {
        print("FAIL  \(name): no refusal alert appeared when adding the Studio Recordings folder")
        failures += 1
    }
    index += 1
    quitAll(app)
}

print(failures == 0 ? "PASS: every real window drew its selected sidebar row with a visible icon and label, and the refusal showed"
                    : "FAIL: \(failures) of \(index) captures failed")
exit(failures == 0 ? 0 : 1)
