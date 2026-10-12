// Captures the REAL Prakriti window in light and in dark: since v2 part M3a, every smart group of the
// Library sidebar, the list, a folder under Sources, the inspector's three tabs, a search over what was
// said, each pane of the Settings window and the Activity window. It checks what the bitmap snapshots
// can only imitate: the selected sidebar row as macOS really draws it (Liquid Glass and the
// accent-colored selection) must show its icon and its label. Reason: on 10 Oct the selected row's
// icon was invisible in the real window (accent icon on an accent selection) while every snapshot
// looked fine. Last, it tries to add the Studio Recordings folder and checks that the development
// refusal alert appears.
//
//   cd ~/Code/prakriti/mac && make look
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift build/Build/Products/Debug/Prakriti.app ../screens/mac/latest/real
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --analyze some-capture.png
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --contrast some-capture.png 488 700 860 735
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --window build/Build/Products/Debug/Prakriti.app out.png
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --help build/Build/Products/Debug/Prakriti.app ../screens/mac/v2-m2a/real
//
// The app opens with --sample-data: the same sample recordings as the snapshots, in memory only,
// so nothing is saved and Ivan's store is never opened. Each launch takes the screen's focus for a
// few seconds (the window must be frontmost for macOS to draw the selection in the accent color).
// Needs no Screen Recording permission on this Mac: `screencapture -l` captures one window.
import AppKit
import CoreGraphics
import Foundation

/// One capture of `make look`: its name, its launch flags after --sample-data, which window it captures,
/// and whether the sidebar must have the focus (its selection drawn in the accent).
struct Look {
    enum Window { case main, settings, activity }
    let name: String
    let flags: [String]
    var window: Window = .main
    var accent = false
}
let looks: [Look] = [
    Look(name: "01-needs-you", flags: ["--show=needs-you"], accent: true),
    Look(name: "02-in-progress", flags: ["--show=in-progress"]),
    Look(name: "03-ready", flags: ["--show=ready"]),
    Look(name: "04-all-recordings", flags: ["--show=all-recordings"]),
    Look(name: "05-all-recordings-list", flags: ["--show=all-recordings", "--browser=list", "--select=readyForYourYes"]),
    Look(name: "06-source", flags: ["--show=source"]),
    Look(name: "07-inspector-outputs", flags: ["--show=needs-you", "--select=readyForYourYes", "--inspector-tab=outputs"]),
    Look(name: "07-inspector-checks", flags: ["--show=needs-you", "--select=readyForYourYes", "--inspector-tab=checks"]),
    Look(name: "07-inspector-info", flags: ["--show=needs-you", "--select=readyForYourYes", "--inspector-tab=info"]),
    Look(name: "08-search-said", flags: ["--show=all-recordings", "--search=Krishnamacharya"]),
] + ["general", "outputs", "models", "privacy", "advanced"].enumerated().map { index, pane in
    Look(name: String(format: "09-settings-%02d-%@", index + 1, pane), flags: ["--show=settings-" + pane], window: .settings)
} + [Look(name: "10-activity", flags: ["--show=activity"], window: .activity)]
/// WorkingTicker.interval in the app: how long each working frame shows.
let workingFrameSeconds = 0.7
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
    // The sidebar column, below the title bar: the sidebar is 220 of the window's 1440 points (since
    // v2 part M3a; 1180 before), so the first 14% of the width stays inside it (the page beside it is a
    // different color).
    let columnWidth = w * 14 / 100
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

/// The app's main window: the widest one, wider than any alert. The widest, because since v2 part M2b a
/// development copy can show the welcome (720 pt) beside the main window (1180 pt).
func mainWindowID(pid: pid_t) -> (CGWindowID, CGRect)? {
    layerZeroWindows(pid: pid).filter { $0.1.width > 600 }.max { $0.1.width < $1.1.width }
}

/// The welcome window (v2 part M2b): 720 pt wide, so never the main window (1180) or Help (960).
func welcomeWindows(pid: pid_t) -> [(CGWindowID, CGRect)] {
    layerZeroWindows(pid: pid).filter { abs($0.1.width - 720) < 2 }
}

/// The development log, and its lines from a given count on (each launch is read from where the log
/// stood before it). Every development copy and every capture writes here (warning 26).
let developmentLog = FileManager.default.homeDirectoryForCurrentUser
    .appending(path: "Library/Logs/Prakriti/Development")
func developmentLogLines() -> [String] {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    let file = developmentLog.appending(path: f.string(from: Date()) + ".log")
    return ((try? String(contentsOf: file, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
}
/// A log line's time ("2026-10-11 13:39:34  ...").
func logTime(_ line: String) -> Date? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f.date(from: String(line.prefix(19)))
}

// Accessibility, always by process id: System Events finds a process by name, and the live and the
// development copies are both named Prakriti (warning 79).
func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
    return (value as? [AXUIElement]) ?? []
}
func axString(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return value as? String
}
func axAll(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 25 else { return [] }
    return [element] + axChildren(element).flatMap { axAll($0, depth: depth + 1) }
}
/// The titles of the items in one of the app's menus, read through its menu bar.
func menuItems(pid: pid_t, menu title: String) -> [(title: String, element: AXUIElement)] {
    let app = AXUIElementCreateApplication(pid)
    var bar: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar)
    guard let bar, CFGetTypeID(bar) == AXUIElementGetTypeID() else { return [] }
    let barElement = bar as! AXUIElement
    for item in axChildren(barElement) where axString(item, kAXTitleAttribute) == title {
        for menu in axChildren(item) {
            return axChildren(menu).compactMap { child in
                axString(child, kAXTitleAttribute).flatMap { $0.isEmpty ? nil : ($0, child) }
            }
        }
    }
    return []
}
/// The welcome window's "N of 5", read from its text, or nil when no welcome is open.
func welcomePosition(pid: pid_t) -> String? {
    let app = AXUIElementCreateApplication(pid)
    for element in axAll(app) {
        for attribute in [kAXValueAttribute, kAXDescriptionAttribute, kAXTitleAttribute] {
            if let text = axString(element, attribute), let range = text.range(of: #"\d of \d"#, options: .regularExpression) {
                return String(text[range])
            }
        }
    }
    return nil
}
/// Presses the button with this title in the app's windows.
@discardableResult
func pressButton(pid: pid_t, _ title: String) -> Bool {
    let app = AXUIElementCreateApplication(pid)
    for element in axAll(app) where axString(element, kAXRoleAttribute) == kAXButtonRole as String
        && (axString(element, kAXTitleAttribute) == title || axString(element, kAXDescriptionAttribute) == title) {
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }
    return false
}
/// One key, with modifiers, sent to the app's own event queue.
func sendKey(pid: pid_t, _ key: CGKeyCode, flags: CGEventFlags = []) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)
        event?.flags = flags
        event?.postToPid(pid)
        Thread.sleep(forTimeInterval: 0.05)
    }
}

// MARK: The live preferences

// Every copy of Prakriti shares one bundle identifier, so AppKit saves the window and split-view sizes of a
// capture or development copy into the LIVE copy's preferences domain. On 11 Oct `make look` changed
// `NSSplitView Subview Frames main` (220/860x795 to 220/1220x900) and the Settings window's frame in Ivan's
// preferences. The app now switches that saving off in these modes (LayoutAutosave); this is the second
// line: the layout keys are read before the first launch and, at exit, any key a run changed is put back
// (one it added is removed) and read again. A key that cannot be put back fails the run (exit 3).
let liveDomain = "studio.therowan.prakriti.app" as CFString
let layoutPrefixes = ["NSWindow Frame ", "NSSplitView Subview Frames ", "NSToolbar Configuration ", "NSTableView ", "NSOutlineView ", "NSNavPanel"]
func liveLayout() -> [String: NSObject] {
    CFPreferencesAppSynchronize(liveDomain)
    let keys = (CFPreferencesCopyKeyList(liveDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]) ?? []
    var result: [String: NSObject] = [:]
    for key in keys where layoutPrefixes.contains(where: key.hasPrefix) {
        if let value = CFPreferencesCopyValue(key as CFString, liveDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? NSObject { result[key] = value }
    }
    return result
}
let liveLayoutBefore = liveLayout()
/// Every way out of this script goes through here (`swift` running a script does not run atexit handlers:
/// measured 12 Oct), so the live layout keys are checked and put back at every exit.
func finish(_ code: Int32) -> Never {
    Thread.sleep(forTimeInterval: 1)  // a quit copy's last writes reach cfprefsd first
    let after = liveLayout()
    let changed = Set(after.keys).union(liveLayoutBefore.keys).filter { after[$0] != liveLayoutBefore[$0] }.sorted()
    for key in changed {
        CFPreferencesSetValue(key as CFString, liveLayoutBefore[key], liveDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    if !changed.isEmpty { CFPreferencesSynchronize(liveDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) }
    let now = liveLayout()
    let still = Set(now.keys).union(liveLayoutBefore.keys).filter { now[$0] != liveLayoutBefore[$0] }.sorted()
    print("Live preferences (\(liveDomain)): \(liveLayoutBefore.count) layout keys read before; changed by this run: \(changed.isEmpty ? "none" : changed.joined(separator: "; ")); "
          + (still.isEmpty ? "all as before now." : "FAIL, still different: \(still.joined(separator: "; "))"))
    exit(still.isEmpty ? code : 3)
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
    guard let (windowID, _) = found else { print("FAIL  no Prakriti window to capture"); finish(1) }
    NSRunningApplication(processIdentifier: pid)?.activate()
    Thread.sleep(forTimeInterval: 2.0)
    let (status, text) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(windowID), png.path])
    guard status == 0 else { print("FAIL  screencapture said \(text)"); finish(1) }
    let size = NSImageRep(contentsOf: png).map { "\($0.pixelsWide)x\($0.pixelsHigh) px" } ?? "unreadable"
    print("      saved \(png.path), \(size)")
    finish(0)
}
// The app icon as Finder and the Dock get it (NSWorkspace, which reads the built bundle's compiled
// icon), drawn at 512 and 32 px, with a 32 px copy magnified 8 times for looking. It measures the
// mark too: the rows of the cut (where the ultramarine almost vanishes across the middle) and how far
// the upper half sits right of the lower half. The cut disc has both; v1's plain dot has neither.
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --app-icon build/Build/Products/Debug/Prakriti.app ../screens/mac/v2-m1
if args.first == "--app-icon", args.count == 3 {
    let app = URL(fileURLWithPath: args[1]).standardizedFileURL
    let out = URL(fileURLWithPath: args[2]).standardizedFileURL
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let icon = NSWorkspace.shared.icon(forFile: app.path)
    var cut = true
    for pixels in [512, 32] {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { finish(1) }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let png = out.appending(path: "app-icon-\(pixels).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: png)
        // The mark: clearly blue pixels (ultramarine is about rgb(35, 55, 198); dark is rgb(68, 89, 232)).
        var rows: [(count: Int, sumX: Int)] = Array(repeating: (0, 0), count: pixels)
        for y in 0..<pixels {
            for x in 0..<pixels {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let (r, g, b) = (Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
                if b > r + 60 && b > g + 60 && c.alphaComponent > 0.5 { rows[y].count += 1; rows[y].sumX += x }
            }
        }
        let marked = rows.indices.filter { rows[$0].count > 0 }
        guard let top = marked.first, let bottom = marked.last else { print("FAIL  \(pixels) px: no ultramarine mark found"); cut = false; continue }
        let widest = rows.map(\.count).max() ?? 1
        let middle = (top + (bottom - top) * 3 / 10)...(top + (bottom - top) * 7 / 10)
        let gap = middle.filter { rows[$0].count * 10 < widest }
        // The thinnest row in the middle splits the mark into its two halves.
        let split = gap.isEmpty ? middle.min { rows[$0].count < rows[$1].count }! : gap[gap.count / 2]
        func centre(_ range: ClosedRange<Int>) -> Double {
            let n = range.reduce(0) { $0 + rows[$1].count }, sx = range.reduce(0) { $0 + rows[$1].sumX }
            return n == 0 ? 0 : Double(sx) / Double(n)
        }
        let shift = centre(top...split) - centre(split...bottom)   // image rows run top down
        let dip = Double(rows[split].count) / Double(widest)
        print(String(format: "      %d px: mark rows %d to %d, widest %d px; cut: %d empty rows, thinnest middle row %.0f%% of the widest; upper half %.1f px right of the lower half; saved %@",
                     pixels, top, bottom, widest, gap.count, dip * 100, shift, png.lastPathComponent))
        let threshold = Double(pixels) / 512 * 20
        if shift < threshold || (pixels >= 256 && gap.isEmpty) { cut = false }
        if pixels <= 64 {
            // Magnified 8 times, pixel for pixel, for looking at a small size.
            let big = pixels * 8
            if let zoom = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: big, pixelsHigh: big, bitsPerSample: 8,
                                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                           bytesPerRow: 0, bitsPerPixel: 0) {
                NSGraphicsContext.saveGraphicsState()
                let context = NSGraphicsContext(bitmapImageRep: zoom)
                context?.imageInterpolation = .none
                NSGraphicsContext.current = context
                rep.draw(in: NSRect(x: 0, y: 0, width: big, height: big), from: .zero, operation: .copy, fraction: 1,
                         respectFlipped: false, hints: [.interpolation: NSNumber(value: NSImageInterpolation.none.rawValue)])
                NSGraphicsContext.restoreGraphicsState()
                try? zoom.representation(using: .png, properties: [:])?.write(to: out.appending(path: "app-icon-\(pixels)-x8.png"))
            }
        }
    }
    print(cut ? "PASS  the cut disc: a cut across the middle and the halves set apart" : "FAIL  not the cut disc (no cut, or the halves are not set apart)")
    finish(cut ? 0 : 1)
}
// The menu bar, as the Window Server draws it, read for every Prakriti mark it shows. It captures the
// system's own menu bar window again and again for the given number of seconds, finds each Prakriti
// item by comparing every item in the bar with the seven glyphs in the app's asset catalog (their
// coverage, so a dim half counts), and prints, per item, which glyph it showed and when it changed:
// the working frames must alternate every 0.7 s, and every other state must hold still. Saves the
// first capture of each Prakriti item, magnified 8 times, to the folder. Read only: it clicks nothing.
// It needs Screen Recording permission for whatever runs it (the v2 part M1 session had it, through
// the app it ran in; CGPreflightScreenCaptureAccess said yes).
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --menu-bar build/Build/Products/Debug/Prakriti.app 10 ../screens/mac/v2-m1/menubar
if args.first == "--menu-bar", args.count == 4, let seconds = Double(args[2]) {
    let app = URL(fileURLWithPath: args[1]).standardizedFileURL
    let out = URL(fileURLWithPath: args[3]).standardizedFileURL
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let names = ["prakriti-menubar", "prakriti-menubar-working-1", "prakriti-menubar-working-2", "prakriti-menubar-waiting",
                 "prakriti-menubar-problem", "prakriti-menubar-paused", "prakriti-menubar-not-watching"]
    guard let bundle = Bundle(url: app) else { print("FAIL  cannot open \(app.path)"); finish(1) }
    let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
    guard let bar = list.first(where: { ($0[kCGWindowName as String] as? String) == "Menubar" && ($0[kCGWindowOwnerName as String] as? String) == "Window Server" }),
          let barNumber = bar[kCGWindowNumber as String] as? Int,
          let barBounds = (bar[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0) }) else {
        print("FAIL  no menu bar window found"); finish(1)
    }
    let shot = FileManager.default.temporaryDirectory.appending(path: "prakriti-menubar-\(getpid()).png")
    /// One capture of the menu bar: its coverage (alpha, 0 to 1) per pixel.
    func capture() -> (alpha: [Float], width: Int, height: Int, rep: NSBitmapImageRep)? {
        let (status, _) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(barNumber), shot.path])
        guard status == 0, let rep = NSBitmapImageRep(data: (try? Data(contentsOf: shot)) ?? Data()) else { return nil }
        var alpha = [Float](repeating: 0, count: rep.pixelsWide * rep.pixelsHigh)
        var p = [Int](repeating: 0, count: 4)
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide { rep.getPixel(&p, atX: x, y: y); alpha[y * rep.pixelsWide + x] = Float(p[rep.samplesPerPixel - 1]) / 255 } }
        return (alpha, rep.pixelsWide, rep.pixelsHigh, rep)
    }
    guard let first = capture() else { print("FAIL  the menu bar could not be captured (screencapture)"); finish(1) }
    let scale = Int((Double(first.height) / barBounds.height).rounded())
    let side = 18 * scale
    // Each glyph's coverage at the capture's scale.
    var glyphs: [(name: String, alpha: [Float])] = []
    for name in names {
        guard let image = bundle.image(forResource: name) else { print("FAIL  \(name) is not in \(app.lastPathComponent)"); finish(1) }
        var bytes = [UInt8](repeating: 0, count: side * side)
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return }
            // A bitmap context's first row in memory is the top of the picture, as in the capture.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
        glyphs.append((name, bytes.map { Float($0) / 255 }))
    }
    /// The bar's items: runs of columns with something drawn, split by gaps of at least 3 pt.
    func items(_ c: (alpha: [Float], width: Int, height: Int, rep: NSBitmapImageRep)) -> [ClosedRange<Int>] {
        var columns = [Bool](repeating: false, count: c.width)
        for x in 0..<c.width { for y in 0..<c.height where c.alpha[y * c.width + x] > 0.04 { columns[x] = true; break } }
        var runs: [ClosedRange<Int>] = [], start = -1, lastOn = -100
        for x in 0..<c.width where columns[x] {
            if x - lastOn > 3 * scale { if start >= 0 { runs.append(start...lastOn) }; start = x }
            lastOn = x
        }
        if start >= 0 { runs.append(start...lastOn) }
        return runs.filter { $0.count <= side + 2 * scale && $0.count >= 8 * scale }
    }
    /// The glyph an item shows and how far it is from it: the mean coverage difference over the
    /// glyph's square at the best placement near the item's centre (0 is identical).
    func classify(_ c: (alpha: [Float], width: Int, height: Int, rep: NSBitmapImageRep), _ item: ClosedRange<Int>) -> (name: String, distance: Float, x: Int, y: Int) {
        var best: (String, Float, Int, Int) = ("", .infinity, 0, 0)
        let cx = (item.lowerBound + item.upperBound) / 2 - side / 2, cy = (c.height - side) / 2
        for glyph in glyphs {
            for dx in -3 * scale...3 * scale { for dy in -2 * scale...2 * scale {
                let x0 = cx + dx, y0 = cy + dy
                guard x0 >= 0, y0 >= 0, x0 + side <= c.width, y0 + side <= c.height else { continue }
                var sum: Float = 0
                for y in 0..<side { for x in 0..<side { sum += abs(c.alpha[(y0 + y) * c.width + x0 + x] - glyph.alpha[y * side + x]) } }
                let mean = sum / Float(side * side)
                if mean < best.1 { best = (glyph.name, mean, x0, y0) }
            } }
        }
        return best
    }
    let prakriti: [(range: ClosedRange<Int>, first: (name: String, distance: Float, x: Int, y: Int))] =
        items(first).map { ($0, classify(first, $0)) }.filter { $0.1.distance < 0.06 }
    guard !prakriti.isEmpty else {
        // Other apps' items come back only with Screen Recording permission for whatever runs this.
        print("FAIL  no Prakriti mark in the menu bar (\(items(first).count) items read; Screen Recording permission for this process: \(CGPreflightScreenCaptureAccess() ? "yes" : "no, so the bar may come back empty"))")
        finish(1)
    }
    for (n, item) in prakriti.enumerated() {
        // Magnified 8 times over mid grey, so the glyph and its dim half can be seen.
        let zoom = 8, w = side * zoom
        guard let png = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: w, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                         isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
        for y in 0..<side { for x in 0..<side {
            let a = first.alpha[(item.first.y + y) * first.width + item.first.x + x]
            var p = [Int(110 + 145 * a), Int(110 + 145 * a), Int(110 + 145 * a)]
            for zy in 0..<zoom { for zx in 0..<zoom { png.setPixel(&p, atX: x * zoom + zx, y: y * zoom + zy) } }
        } }
        try? png.representation(using: .png, properties: [:])?.write(to: out.appending(path: "menubar-item-\(n + 1)-\(item.first.name).png"))
    }
    // The timeline: capture again and again, and note every change of glyph per item.
    let started = Date()
    var timeline: [[(t: Double, name: String)]] = prakriti.map { [(0, $0.first.name)] }
    var captures = 1
    while Date().timeIntervalSince(started) < seconds {
        guard let c = capture() else { continue }
        captures += 1
        let t = Date().timeIntervalSince(started)
        for (n, item) in prakriti.enumerated() {
            let now = classify(c, item.range)
            if now.distance < 0.06, now.name != timeline[n].last?.name { timeline[n].append((t, now.name)) }
        }
    }
    let elapsed = Date().timeIntervalSince(started)
    print(String(format: "      %d captures of the menu bar in %.1f s (one every %.2f s), from %@", captures, elapsed,
                 elapsed / Double(captures), started.formatted(date: .omitted, time: .standard)))
    // Read per item as a run of segments: the working frames alternating, or one state held still.
    var animatedRight = true, sawTurning = false
    for (n, item) in prakriti.enumerated() {
        let x = Double(item.range.lowerBound) / Double(scale) + barBounds.minX
        print(String(format: "      item %d at x %.0f pt (its first glyph %.3f from the asset):", n + 1, x, item.first.distance))
        var changes = timeline[n][...]
        while let head = changes.first {
            let isWorking = head.name.contains("working")
            let run = isWorking ? changes.prefix { $0.name.contains("working") } : changes.prefix(1)
            changes = changes.dropFirst(run.count)
            let end = changes.first?.t ?? elapsed
            let label = head.name.replacingOccurrences(of: "prakriti-menubar", with: "mark")
            if isWorking && run.count >= 3 {
                let mean = (run.last!.t - run.first!.t) / Double(run.count - 1)
                sawTurning = true
                print(String(format: "        %5.1f to %5.1f s: the working frames alternating, %d changes, one every %.2f s on average",
                             head.t, end, run.count - 1, mean))
                if abs(mean - workingFrameSeconds) > 0.1 { animatedRight = false; print("        FAIL  not every 0.7 s") }
            } else if isWorking && end - head.t > 2 * workingFrameSeconds {
                print(String(format: "        %5.1f to %5.1f s: one working frame held still (Reduce Motion on, or the ticker stopped)", head.t, end))
            } else {
                print(String(format: "        %5.1f to %5.1f s: %@, held still", head.t, end, isWorking ? "working frames" : label))
            }
        }
    }
    try? FileManager.default.removeItem(at: shot)
    print(!animatedRight ? "FAIL  the working frames did not turn every 0.7 s (see above)"
          : sawTurning ? "PASS  the working frames turned every 0.7 s, and every other state held still"
          : "PASS  every state held still (nothing was working during the capture)")
    finish(animatedRight ? 0 : 1)
}
// Prakriti Help (v2 part M2a): the REAL Help window, opened on its own with sample data
// (`--sample-data --show=help`) at three articles and at a search, in light and dark, each captured with
// `screencapture -l`. The welcome (v2 part M2b): each of its five panels opened on its own
// (`--show=welcome --welcome-panel=N`), light and dark, plus the last panel after Choose Folder added a
// folder and after the development refusal, each alone and fitting without scrolling (the window's own
// measurement, read from the log); Help, Welcome to Prakriti chosen through Accessibility; Continue,
// Return, Command-Left, Back and Escape on the welcome it opened. Then the Help menu's own search handler,
// run through the debug switch `--debug-help-search` for three words, must list the expected article
// first. Writes acceptance-help.txt in the folder above the pictures. Neither window shows a recording, so
// no picture of anyone is made.
//   cd ~/Code/prakriti/mac && make accept-help MILESTONE=v2-m2a
if args.first == "--help", args.count == 3 {
    let app = URL(fileURLWithPath: args[1]).standardizedFileURL
    let out = URL(fileURLWithPath: args[2]).standardizedFileURL
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var report: [String] = ["Prakriti Help and the welcome, real windows and the Help menu (v2 parts M2a and M2b)", "App: \(app.path)", ""]
    var failures = 0
    func say(_ line: String) { print(line); report.append(line) }
    quitAll(app)
    let pages: [(name: String, flags: [String])] = [
        ("sources-and-watching", ["--help-article=sources-and-watching"]),
        ("capture-the-best-video", ["--help-article=capture-the-best-video"]),
        ("troubleshooting", ["--help-article=troubleshooting"]),
        ("search-obs", ["--help-search=OBS"]),
    ]
    for appearance in appearances {
        for (index, page) in pages.enumerated() {
            let name = String(format: "help-%02d-%@-%@", index + 1, page.name, appearance)
            run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--show=help", "--appearance=" + appearance] + page.flags)
            var windows: [(CGWindowID, CGRect)] = []
            var pid: pid_t = 0
            let deadline = Date().addingTimeInterval(15)
            while windows.isEmpty && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.3)
                if let first = pids(of: app).first { pid = first; windows = layerZeroWindows(pid: pid).filter { $0.1.width > 600 } }
            }
            guard let window = windows.first else {
                say("FAIL  \(name): the Help window did not appear within 15 s"); failures += 1; quitAll(app); continue
            }
            NSRunningApplication(processIdentifier: pid)?.activate()
            Thread.sleep(forTimeInterval: 2.0)
            // Help opens alone: the main window stays closed, so the capture is of Help and nothing else.
            let all = layerZeroWindows(pid: pid).filter { $0.1.width > 600 }
            let png = out.appending(path: name + ".png")
            let (status, text) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.0), png.path])
            if status != 0 {
                say("FAIL  \(name): screencapture said \(text.trimmingCharacters(in: .whitespacesAndNewlines))"); failures += 1
            } else {
                let size = NSImageRep(contentsOf: png).map { "\($0.pixelsWide)x\($0.pixelsHigh) px" } ?? "unreadable"
                let alone = all.count == 1
                if !alone { failures += 1 }
                // The bounds read after the window settled (read while it opens, they are still growing).
                let settled = all.first { $0.0 == window.0 }?.1 ?? window.1
                say("\(alone ? "PASS" : "FAIL")  \(name): \(Int(settled.width))x\(Int(settled.height)) pt window, \(all.count) window(s) open, saved \(png.lastPathComponent) (\(size))")
            }
            quitAll(app)
        }
    }
    // The welcome (v2 part M2b): each of its five panels alone (`--sample-data --show=welcome`), light and
    // dark, then the last panel after Choose Folder added a folder and after the development refusal. Each
    // must be the only window open, and its panel must fit without scrolling, as the window itself
    // measured it and wrote to the log. The welcome shows no recording, so no picture of anyone is made.
    say("")
    let addedFolder = FileManager.default.temporaryDirectory.appending(path: "Welcome check folder", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: addedFolder, withIntermediateDirectories: true)
    let studio = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/Design Work/Galindo x Lizarde/Studio Recordings "
    var welcomePages: [(name: String, panel: Int, flags: [String])] = (1...5).map { ("welcome-\($0)", $0, []) }
    welcomePages.append(("welcome-5-folder-added", 5, ["--welcome-folder=" + addedFolder.path]))
    // --development: the refusal belongs to a test copy. Refused, so nothing is added, even in memory.
    welcomePages.append(("welcome-5-folder-refused", 5, ["--development", "--welcome-folder=" + studio]))
    for appearance in appearances {
        for page in welcomePages {
            let name = "\(page.name)-\(appearance)"
            let mark = developmentLogLines().count
            run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--show=welcome", "--welcome-panel=\(page.panel)",
                                  "--appearance=" + appearance] + page.flags)
            var windows: [(CGWindowID, CGRect)] = []
            var pid: pid_t = 0
            let deadline = Date().addingTimeInterval(15)
            while windows.isEmpty && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.3)
                if let first = pids(of: app).first { pid = first; windows = welcomeWindows(pid: pid) }
            }
            guard let window = windows.first else {
                say("FAIL  \(name): the welcome did not appear within 15 s"); failures += 1; quitAll(app); continue
            }
            NSRunningApplication(processIdentifier: pid)?.activate()
            Thread.sleep(forTimeInterval: 2.0)
            let all = layerZeroWindows(pid: pid)
            let png = out.appending(path: name + ".png")
            let (status, text) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.0), png.path])
            let lines = developmentLogLines().dropFirst(mark)
            let fit = lines.first { $0.contains("Welcome panel \(page.panel) of 5") }
            let fits = fit?.contains(" fits: ") ?? false
            if status != 0 {
                say("FAIL  \(name): screencapture said \(text.trimmingCharacters(in: .whitespacesAndNewlines))"); failures += 1
            } else {
                let size = NSImageRep(contentsOf: png).map { "\($0.pixelsWide)x\($0.pixelsHigh) px" } ?? "unreadable"
                let settled = all.first { $0.0 == window.0 }?.1 ?? window.1
                let ok = all.count == 1 && fits
                if !ok { failures += 1 }
                say("\(ok ? "PASS" : "FAIL")  \(name): \(Int(settled.width))x\(Int(settled.height)) pt window, \(all.count) window(s) open, "
                    + "\(fit.map { String($0.dropFirst(21)) } ?? "no fit line in the log"), saved \(png.lastPathComponent) (\(size))")
            }
            quitAll(app)
        }
    }
    try? FileManager.default.removeItem(at: addedFolder)

    // Help, Welcome to Prakriti, chosen through Accessibility in a copy showing Help alone; then the
    // welcome it opened is driven by its buttons and keys: Continue, Return, Command-Left, Back, Escape.
    say("")
    run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--show=help", "--appearance=light"])
    var helpPid: pid_t = 0
    let helpDeadline = Date().addingTimeInterval(15)
    while helpPid == 0 && Date() < helpDeadline {
        Thread.sleep(forTimeInterval: 0.3)
        if let first = pids(of: app).first, !layerZeroWindows(pid: first).isEmpty { helpPid = first }
    }
    if helpPid == 0 {
        say("FAIL  the Help window did not appear for the Help menu check"); failures += 1
    } else {
        NSRunningApplication(processIdentifier: helpPid)?.activate()
        Thread.sleep(forTimeInterval: 1.5)
        let items = menuItems(pid: helpPid, menu: "Help")
        let titles = items.map(\.title)
        let listed = titles.contains("Prakriti Help") && titles.contains("Welcome to Prakriti") && titles.contains("Show Log in Finder")
        if !listed { failures += 1 }
        say("\(listed ? "PASS" : "FAIL")  the Help menu lists: \(titles.joined(separator: ", "))")
        let mark = developmentLogLines().count
        if let item = items.first(where: { $0.title == "Welcome to Prakriti" }) {
            AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        }
        var welcome: [(CGWindowID, CGRect)] = []
        let deadline = Date().addingTimeInterval(10)
        while welcome.isEmpty && Date() < deadline { Thread.sleep(forTimeInterval: 0.3); welcome = welcomeWindows(pid: helpPid) }
        let shownLine = developmentLogLines().dropFirst(mark).first { $0.contains("Welcome shown (Help, Welcome to Prakriti)") }
        let opened = !welcome.isEmpty && shownLine != nil
        if !opened { failures += 1 }
        say("\(opened ? "PASS" : "FAIL")  Help, Welcome to Prakriti opened the welcome (\(welcome.first.map { "\(Int($0.1.width))x\(Int($0.1.height)) pt" } ?? "no window")) at \(welcomePosition(pid: helpPid) ?? "no panel"); log: \(shownLine.map { String($0.dropFirst(21)) } ?? "nothing")")
        if let window = welcome.first {
            run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.0), out.appending(path: "welcome-from-help-menu.png").path])
            NSRunningApplication(processIdentifier: helpPid)?.activate()
            Thread.sleep(forTimeInterval: 1.0)
            var steps: [(String, String, String?)] = []
            func step(_ what: String, expect: String?, _ act: () -> Void) {
                act()
                Thread.sleep(forTimeInterval: 0.8)
                let now = welcomeWindows(pid: helpPid).isEmpty ? nil : welcomePosition(pid: helpPid)
                steps.append((what, expect ?? "closed", now ?? (welcomeWindows(pid: helpPid).isEmpty ? "closed" : "open, position unread")))
            }
            step("Continue clicked", expect: "2 of 5") { pressButton(pid: helpPid, "Continue") }
            step("Return pressed", expect: "3 of 5") { sendKey(pid: helpPid, 36) }
            step("Command-Left pressed", expect: "2 of 5") { sendKey(pid: helpPid, 123, flags: .maskCommand) }
            step("Back clicked", expect: "1 of 5") { pressButton(pid: helpPid, "Back") }
            step("Escape pressed", expect: nil) { sendKey(pid: helpPid, 53) }
            for (what, expected, got) in steps {
                let ok = expected == got
                if !ok { failures += 1 }
                say("\(ok ? "PASS" : "FAIL")  \(what): \(got ?? "nothing") (expected \(expected))")
            }

            // Opened again from the Help menu: the panel 2 link opens its article in Help, and Start Using
            // Prakriti on the last panel closes the welcome and opens the main window.
            func helpTitle() -> String? {
                let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
                return list.first { ($0[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == helpPid
                    && ($0[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }.map { abs($0.width - 960) < 2 } == true }
                    .flatMap { $0[kCGWindowName as String] as? String }
            }
            if let item = menuItems(pid: helpPid, menu: "Help").first(where: { $0.title == "Welcome to Prakriti" }) {
                AXUIElementPerformAction(item.element, kAXPressAction as CFString)
                Thread.sleep(forTimeInterval: 1.0)
            }
            pressButton(pid: helpPid, "Continue")
            Thread.sleep(forTimeInterval: 0.6)
            let helpBefore = helpTitle() ?? "no Help window"
            let linkPressed = pressButton(pid: helpPid, "More in Help: Capture the best video")
            Thread.sleep(forTimeInterval: 1.0)
            let helpAfter = helpTitle() ?? "no Help window"
            let linkOK = linkPressed && helpAfter == "Capture the best video"
            if !linkOK { failures += 1 }
            say("\(linkOK ? "PASS" : "FAIL")  More in Help: Capture the best video, on panel 2: the Help window went from \"\(helpBefore)\" to \"\(helpAfter)\"")
            for _ in 0..<3 { pressButton(pid: helpPid, "Continue"); Thread.sleep(forTimeInterval: 0.5) }
            let lastPanel = welcomePosition(pid: helpPid) ?? "unread"
            pressButton(pid: helpPid, "Start Using Prakriti")
            var mainOpened = false
            let mainDeadline = Date().addingTimeInterval(8)
            while !mainOpened && Date() < mainDeadline {
                Thread.sleep(forTimeInterval: 0.3)
                mainOpened = layerZeroWindows(pid: helpPid).contains { abs($0.1.width - 1180) < 2 }
            }
            let welcomeClosed = welcomeWindows(pid: helpPid).isEmpty
            let startOK = lastPanel == "5 of 5" && mainOpened && welcomeClosed
            if !startOK { failures += 1 }
            say("\(startOK ? "PASS" : "FAIL")  Start Using Prakriti at \(lastPanel): the welcome \(welcomeClosed ? "closed" : "stayed open"), the main window \(mainOpened ? "opened" : "did not open")")
        }
    }
    quitAll(app)

    // The Help menu's search handler, through the debug switch: it prints the article ids it returns.
    let binary = app.appending(path: "Contents/MacOS/Prakriti")
    say("")
    for (words, expected) in [("OBS", "set-up-obs-for-prakriti"), ("notifications", "troubleshooting"), ("privacy", "people-and-privacy")] {
        let (status, output) = run(binary.path, ["--debug-help-search=" + words])
        let ids = output.split(separator: "\n").map(String.init).filter { $0.allSatisfy { $0.isLowercase || $0 == "-" } && !$0.isEmpty }
        let ok = status == 0 && ids.first == expected
        if !ok { failures += 1 }
        say("\(ok ? "PASS" : "FAIL")  --debug-help-search=\(words): \(ids.isEmpty ? "nothing" : ids.joined(separator: ", ")) (expected \(expected) first; exit \(status))")
    }
    say("")
    say(failures == 0 ? "PASS: Help opened alone at every article and search, light and dark, and the Help menu's search put the expected article first; the welcome opened alone at every panel, light and dark, each fitting without scrolling, and from the Help menu, and answered its buttons and keys"
                      : "FAIL: \(failures) check(s) failed")
    let file = out.deletingLastPathComponent().appending(path: "acceptance-help.txt")
    try? (report.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    print("      wrote \(file.path)")
    finish(failures == 0 ? 0 : 1)
}
// The first launch (v2 part M2b, docs/v2/PLAN.md M2 check 5), made rather than assumed: the development
// preference `welcomeSeenVersion` is deleted (`defaults delete` on the development domain, never the live
// one), then the built app is opened twice with `--development`, its own store, log and folders. The
// welcome must appear at the first launch only ("Welcome shown" in the log, and its 720 pt window), and the
// watcher's first look ("Checked ...") must come within 5 s of each launch. The live preference is read
// before and after to prove it was not touched. Writes acceptance-first-launch.txt.
//   cd ~/Code/prakriti/mac && make accept-first-launch MILESTONE=v2-m2b
if args.first == "--first-launch", args.count == 3 {
    let app = URL(fileURLWithPath: args[1]).standardizedFileURL
    let out = URL(fileURLWithPath: args[2]).standardizedFileURL
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var report: [String] = ["The welcome at the first launch, and only then (v2 part M2b)", "App: \(app.path)", ""]
    var failures = 0
    func say(_ line: String) { print(line); report.append(line) }
    let developmentDomain = "studio.therowan.prakriti.app.development"
    let liveDomain = "studio.therowan.prakriti.app"
    func preference(_ domain: String) -> String {
        let (status, text) = run("/usr/bin/defaults", ["read", domain, "welcomeSeenVersion"])
        return status == 0 ? text.trimmingCharacters(in: .whitespacesAndNewlines) : "not set"
    }
    /// The last panel's buttons in the real window, on the first launch's welcome: Continue to panel 5;
    /// Choose Folder... must open the system's Open panel (Cancel closes it, nothing is added); and the
    /// notification button is pressed only when it reads Open Notification Settings... (macOS already has
    /// a no), never Turn On Notifications, which would put macOS's own question on Ivan's screen for the
    /// permission the live copy shares. System Settings must then open at Prakriti's page; it is quit
    /// again only if it was not open before.
    func lastPanelButtons(pid: pid_t, window: CGWindowID) {
        NSRunningApplication(processIdentifier: pid)?.activate()
        for _ in 0..<4 { pressButton(pid: pid, "Continue"); Thread.sleep(forTimeInterval: 0.6) }
        let position = welcomePosition(pid: pid) ?? "unread"
        let atLast = position == "5 of 5"
        if !atLast { failures += 1 }
        let png = out.appending(path: "first-launch-panel-5.png")
        run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window), png.path])
        say("\(atLast ? "PASS" : "FAIL")  Continue four times reached \(position); saved \(png.lastPathComponent)")

        let before = layerZeroWindows(pid: pid).count
        let pressedChoose = pressButton(pid: pid, "Choose Folder…")
        var panelOpened = false
        let deadline = Date().addingTimeInterval(8)
        while !panelOpened && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            panelOpened = layerZeroWindows(pid: pid).count > before
        }
        let cancelled = panelOpened && pressButton(pid: pid, "Cancel")
        Thread.sleep(forTimeInterval: 0.8)
        let closedAgain = layerZeroWindows(pid: pid).count == before
        let chooseOK = pressedChoose && panelOpened && cancelled && closedAgain
        if !chooseOK { failures += 1 }
        say("\(chooseOK ? "PASS" : "FAIL")  Choose Folder… opened the system's Open panel (\(panelOpened ? "a window more" : "no new window")), and Cancel closed it\(closedAgain ? "" : ": a window is still open")")

        let titles = axAll(AXUIElementCreateApplication(pid))
            .filter { axString($0, kAXRoleAttribute) == kAXButtonRole as String }
            .compactMap { button in [kAXTitleAttribute, kAXDescriptionAttribute].lazy.compactMap { axString(button, $0) }.first { !$0.isEmpty } }
        guard let notificationButton = titles.first(where: { $0.contains("Notification") }) else {
            say("      the notification row shows no button (notifications are on): nothing to press"); return
        }
        guard notificationButton == "Open Notification Settings…" else {
            say("      the notification button reads \(notificationButton): not pressed, so macOS asks nothing on Ivan's screen"); return
        }
        let settingsWasOpen = !run("/usr/bin/pgrep", ["-f", "System Settings.app/Contents/MacOS/System Settings"]).1.isEmpty
        let mark = developmentLogLines().count
        pressButton(pid: pid, notificationButton)
        var page: String?
        let settingsDeadline = Date().addingTimeInterval(10)
        while page == nil && Date() < settingsDeadline {
            Thread.sleep(forTimeInterval: 0.4)
            let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
            page = list.first { ($0[kCGWindowOwnerName as String] as? String) == "System Settings" && ($0[kCGWindowLayer as String] as? Int) == 0 }
                .flatMap { $0[kCGWindowName as String] as? String }
        }
        let logged = developmentLogLines().dropFirst(mark).first { $0.contains("opened System Settings at Prakriti's Notifications page") }
        let ok = page == "Prakriti" && logged != nil
        if !ok { failures += 1 }
        say("\(ok ? "PASS" : "FAIL")  Open Notification Settings… opened System Settings at the page \(page.map { "\"\($0)\"" } ?? "(none)"); log: \(logged.map { String($0.dropFirst(21)) } ?? "nothing")")
        if !settingsWasOpen {
            run("/usr/bin/osascript", ["-e", "quit app \"System Settings\""])
            say("      System Settings was not open before, so it was quit again")
        }
    }

    quitAll(app)
    // Another development copy (from a clone, say) would hold the development lock, and this launch
    // would quit as its duplicate: stop rather than measure the wrong thing.
    let (_, listing) = run("/usr/bin/pgrep", ["-fl", "Prakriti.app/Contents/MacOS/Prakriti"])
    let others = listing.split(separator: "\n").filter { $0.contains("--development") && !$0.contains("--sample-data") }
    if !others.isEmpty {
        say("FAIL  another development copy is running and holds the development lock: \(others.joined(separator: " | "))")
        finish(1)
    }
    let liveBefore = preference(liveDomain)
    run("/usr/bin/defaults", ["delete", developmentDomain, "welcomeSeenVersion"])
    say("Deleted \(developmentDomain) welcomeSeenVersion: now \(preference(developmentDomain)). Live preference: \(liveBefore).")
    for launch in 1...2 {
        let mark = developmentLogLines().count
        // The log counts whole seconds, so the launch is timed from the start of its second.
        let opened = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        run("/usr/bin/open", ["-n", app.path, "--args", "--development"])
        var pid: pid_t = 0
        var welcome: [(CGWindowID, CGRect)] = []
        var checked: String?
        var lines: [String] = []
        let deadline = Date().addingTimeInterval(launch == 1 ? 25 : 15)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            if pid == 0, let first = pids(of: app).first { pid = first }
            if pid != 0, welcome.isEmpty { welcome = welcomeWindows(pid: pid) }
            lines = Array(developmentLogLines().dropFirst(mark))
            checked = lines.first { $0.contains("  Checked ") && $0.contains(" folder") }
            let settled = checked != nil && lines.contains { $0.contains("Welcome shown at first launch") || $0.contains("Welcome: seen before") }
            if settled && (launch == 2 || !welcome.isEmpty) { break }
        }
        Thread.sleep(forTimeInterval: launch == 2 ? 2.0 : 0.5)
        lines = Array(developmentLogLines().dropFirst(mark))
        if pid != 0, welcome.isEmpty { welcome = welcomeWindows(pid: pid) }
        let start = lines.first { $0.contains("opened. Mode: development") }
        let shown = lines.first { $0.contains("Welcome shown") }
        let seenBefore = lines.first { $0.contains("Welcome: seen before") }
        let noAsk = lines.first { $0.contains("Notifications: not asked at launch") }
        let firstLook = start.flatMap(logTime).flatMap { begin in checked.flatMap(logTime).map { $0.timeIntervalSince(begin) } }
        // Seconds are whole in the log; the time from `open` to the first look is measured here too.
        let fromOpen = checked.flatMap(logTime).map { $0.timeIntervalSince(opened) }
        let lookOK = (firstLook ?? 99) <= 5 && (fromOpen ?? 99) <= 6
        say("")
        say("Launch \(launch) (pid \(pid)):")
        say("      \(start.map { String($0.prefix(19)) } ?? "?")  opened in development mode")
        say("\(lookOK ? "PASS" : "FAIL")  the watcher's first look: \(checked.map { String($0.dropFirst(21)) } ?? "none"), "
            + "\(firstLook.map { String(format: "%.0f s", $0) } ?? "?") after the app's first line, \(fromOpen.map { String(format: "%.0f s", $0) } ?? "?") after open (both in whole seconds)")
        if !lookOK { failures += 1 }
        if launch == 1 {
            let ok = shown != nil && !welcome.isEmpty
            if !ok { failures += 1 }
            say("\(ok ? "PASS" : "FAIL")  the welcome appeared: \(shown.map { String($0.dropFirst(21)) } ?? "no Welcome shown line"); window \(welcome.first.map { "\(Int($0.1.width))x\(Int($0.1.height)) pt" } ?? "none")")
            say("      \(noAsk.map { String($0.dropFirst(21)) } ?? "no line about the notification ask")")
            if let window = welcome.first {
                let png = out.appending(path: "first-launch-welcome.png")
                run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(window.0), png.path])
                say("      saved \(png.lastPathComponent)")
                lastPanelButtons(pid: pid, window: window.0)
            }
        } else {
            let ok = shown == nil && welcome.isEmpty && seenBefore != nil
            if !ok { failures += 1 }
            say("\(ok ? "PASS" : "FAIL")  the welcome did not appear: \(seenBefore.map { String($0.dropFirst(21)) } ?? "no seen-before line"); "
                + "\(shown == nil ? "no Welcome shown line" : "a Welcome shown line"), \(welcome.isEmpty ? "no welcome window" : "a welcome window")")
        }
        // Which window is in front: the window list runs front to back.
        let order = layerZeroWindows(pid: pid).map { abs($0.1.width - 720) < 2 ? "the welcome" : "a \(Int($0.1.width)) pt window" }
        say("      windows, front to back: \(order.isEmpty ? "none" : order.joined(separator: ", "))")
        say("      development preference after launch \(launch): welcomeSeenVersion \(preference(developmentDomain))")
        quitAll(app)
    }
    let liveAfter = preference(liveDomain)
    let liveOK = liveAfter == liveBefore
    if !liveOK { failures += 1 }
    say("")
    say("\(liveOK ? "PASS" : "FAIL")  the live preference was not touched: before \(liveBefore), after \(liveAfter)")
    say(failures == 0 ? "PASS: the welcome appeared at the first launch only, and the watcher looked within 5 s both times"
                      : "FAIL: \(failures) check(s) failed")
    let file = out.deletingLastPathComponent().appending(path: "acceptance-first-launch.txt")
    try? (report.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    print("      wrote \(file.path)")
    finish(failures == 0 ? 0 : 1)
}
// The contrast between the darkest and the lightest pixel in a box of a capture (sRGB, WCAG's formula):
// secondary text on its background, measured as the screen drew it (v2 part M3a, design spec 6.6).
//   swift scripts/capture-window.swift --contrast <png> <x0> <y0> <x1> <y1>   (pixels)
if args.first == "--contrast", args.count == 6, let x0 = Int(args[2]), let y0 = Int(args[3]), let x1 = Int(args[4]), let y1 = Int(args[5]) {
    guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: URL(fileURLWithPath: args[1]))) ?? Data())?
            .converting(to: .sRGB, renderingIntent: .default) else { print("FAIL  could not read \(args[1])"); finish(1) }
    func luminance(_ p: [Int]) -> Double {
        let f = { (v: Int) -> Double in let v = Double(v) / 255; return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(p[0]) + 0.7152 * f(p[1]) + 0.0722 * f(p[2])
    }
    var darkest = [255, 255, 255], lightest = [0, 0, 0]
    for y in y0..<min(y1, rep.pixelsHigh) {
        for x in x0..<min(x1, rep.pixelsWide) {
            var p = [Int](repeating: 0, count: 4)
            rep.getPixel(&p, atX: x, y: y)
            if luminance(p) < luminance(darkest) { darkest = Array(p[0..<3]) }
            if luminance(p) > luminance(lightest) { lightest = Array(p[0..<3]) }
        }
    }
    let ratio = (luminance(lightest) + 0.05) / (luminance(darkest) + 0.05)
    print("\(ratio >= 4.5 ? "PASS" : "FAIL")  \((args[1] as NSString).lastPathComponent) (\(x0),\(y0))-(\(x1),\(y1)): darkest rgb\(darkest), lightest rgb\(lightest), \(String(format: "%.2f", ratio)) to 1")
    finish(ratio >= 4.5 ? 0 : 1)
}
// The main window's keys in the REAL app (v2 part M3a, design spec 2.5 and 6.7), driven through the app's own
// event queue and read back through Accessibility by process id (warning 79): Return and Command-Down open the
// selected recording (the window's title becomes its day), Escape, Command-Up and Command-[ come back (the
// group's name again), Command-2 and Command-1 switch to the list and back (a table appears and goes),
// Command-Option-I hides and shows the inspector (the View menu's item changes its words), Command-comma
// opens the Settings window (760 pt wide); and Escape while typing in the page's title field stays there.
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --keys build/Build/Products/Debug/Prakriti.app
func windowTitles(pid: pid_t) -> [String] {
    let app = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
    return ((value as? [AXUIElement]) ?? []).compactMap { axString($0, kAXTitleAttribute) }
}
/// The list is a table of six columns; Accessibility reads SwiftUI's Table as an outline with columns, and the
/// sidebar is an outline with one, so four or more columns means the list is showing.
func hasTable(pid: pid_t) -> Bool {
    axAll(AXUIElementCreateApplication(pid)).filter { axString($0, kAXRoleAttribute) == kAXColumnRole as String }.count >= 4
}
func runKeysCheck(_ app: URL) -> Int {
    quitAll(app)
    run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--show=needs-you", "--select=readyForYourYes", "--appearance=light"])
    var pid: pid_t = 0
    let deadline = Date().addingTimeInterval(15)
    while Date() < deadline {
        Thread.sleep(forTimeInterval: 0.3)
        if let first = pids(of: app).first, mainWindowID(pid: first) != nil { pid = first; break }
    }
    guard pid != 0 else { print("FAIL  keys: the window did not appear"); return 1 }
    NSRunningApplication(processIdentifier: pid)?.activate()
    Thread.sleep(forTimeInterval: 2.0)
    var failures = 0
    func expect(_ what: String, _ ok: () -> Bool) {
        var passed = false
        let until = Date().addingTimeInterval(3)
        while Date() < until { if ok() { passed = true; break }; Thread.sleep(forTimeInterval: 0.2) }
        if !passed { failures += 1 }
        print("\(passed ? "PASS" : "FAIL")  keys: \(what) (windows: \(windowTitles(pid: pid).joined(separator: ", ")))")
    }
    func title(_ t: String) -> () -> Bool { { windowTitles(pid: pid).contains(t) } }
    expect("opens on Needs You", title("Needs You"))
    sendKey(pid: pid, 36)                                   // Return
    expect("Return opens the selected recording", title("Sun 13 Sep"))
    sendKey(pid: pid, 53)                                   // Escape
    expect("Escape comes back to the group", title("Needs You"))
    sendKey(pid: pid, 125, flags: .maskCommand)             // Command-Down
    expect("Command-Down opens it", title("Sun 13 Sep"))
    sendKey(pid: pid, 126, flags: .maskCommand)             // Command-Up
    expect("Command-Up comes back", title("Needs You"))
    sendKey(pid: pid, 125, flags: .maskCommand)
    expect("Command-Down opens it again", title("Sun 13 Sep"))
    // Escape while typing in a field stays with the field: the page does not close under the typing.
    let field = axAll(AXUIElementCreateApplication(pid)).first { axString($0, kAXRoleAttribute) == kAXTextFieldRole as String
        && axString($0, kAXValueAttribute) == "Talk with Gabriel" }
    if let field {
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        Thread.sleep(forTimeInterval: 0.5)
        sendKey(pid: pid, 53)
        Thread.sleep(forTimeInterval: 1.0)
        expect("Escape while editing the title stays on the page", title("Sun 13 Sep"))
    } else {
        print("FAIL  keys: the page's title field was not found")
        failures += 1
    }
    sendKey(pid: pid, 33, flags: .maskCommand)              // Command-[
    expect("Command-[ comes back", title("Needs You"))
    sendKey(pid: pid, 19, flags: .maskCommand)              // Command-2
    expect("Command-2 shows the list", { hasTable(pid: pid) })
    sendKey(pid: pid, 18, flags: .maskCommand)              // Command-1
    expect("Command-1 shows the grid again", { !hasTable(pid: pid) })
    let before = menuItems(pid: pid, menu: "View").map(\.title).filter { $0.hasSuffix("Inspector") }
    sendKey(pid: pid, 34, flags: [.maskCommand, .maskAlternate])   // Command-Option-I
    expect("Command-Option-I hides the inspector (View menu: \(before.joined()) before)", {
        menuItems(pid: pid, menu: "View").contains { $0.title == "Show Inspector" } })
    sendKey(pid: pid, 34, flags: [.maskCommand, .maskAlternate])
    expect("Command-Option-I shows it again", { menuItems(pid: pid, menu: "View").contains { $0.title == "Hide Inspector" } })
    sendKey(pid: pid, 43, flags: .maskCommand)              // Command-comma
    expect("Command-comma opens the Settings window", { layerZeroWindows(pid: pid).contains { abs($0.1.width - 760) < 2 } })
    quitAll(app)
    return failures
}
if args.first == "--keys", args.count == 2 {
    let failures = runKeysCheck(URL(fileURLWithPath: args[1]).standardizedFileURL)
    print(failures == 0 ? "PASS: every key did what it says" : "FAIL: \(failures) key check(s) failed")
    finish(failures == 0 ? 0 : 1)
}
if args.first == "--analyze" {
    let ok = args.dropFirst().map { describe(($0 as NSString).lastPathComponent, analyze(URL(fileURLWithPath: $0))) }
    finish(ok.allSatisfy { $0 } ? 0 : 1)
}
guard args.count == 2 else {
    print("usage: swift scripts/capture-window.swift <Prakriti.app> <output folder>")
    print("       swift scripts/capture-window.swift --analyze <png>...")
    finish(2)
}
let app = URL(fileURLWithPath: args[0]).standardizedFileURL
let out = URL(fileURLWithPath: args[1]).standardizedFileURL
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

quitAll(app)
var failures = 0
var index = 0
for appearance in appearances {
    for look in looks {
        index += 1
        let name = look.name + "-" + appearance
        // One word per flag: a value given as its own word reads to macOS as a file to open, and
        // then the app does not open its window.
        run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--appearance=" + appearance] + look.flags)
        var found: (CGWindowID, CGRect)?
        var pid: pid_t = 0
        let deadline = Date().addingTimeInterval(15)
        while found == nil && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            if let first = pids(of: app).first {
                pid = first
                switch look.window {
                case .main: found = mainWindowID(pid: pid)
                // The Settings window is 760 pt wide (its panes), the Activity window 720 pt to start.
                case .settings: found = layerZeroWindows(pid: pid).first { abs($0.1.width - 760) < 2 }
                case .activity: found = layerZeroWindows(pid: pid).first { abs($0.1.width - 720) < 2 && $0.1.height > 500 }
                }
            }
        }
        guard let (windowID, bounds) = found else {
            print("FAIL  \(name): the window did not appear within 15 s")
            failures += 1
            quitAll(app)
            continue
        }
        // Let SwiftUI lay out and the glass settle (a search is typed a second after the window opens), and
        // make sure the window is frontmost.
        NSRunningApplication(processIdentifier: pid)?.activate()
        Thread.sleep(forTimeInterval: 2.5)
        let png = out.appending(path: name + ".png")
        let (status, text) = run("/usr/sbin/screencapture", ["-x", "-o", "-l", String(windowID), png.path])
        if status != 0 {
            print("FAIL  \(name): screencapture said \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
            failures += 1
        } else {
            let size = NSImageRep(contentsOf: png).map { "\($0.pixelsWide)x\($0.pixelsHigh) px" } ?? "unreadable"
            print("      \(name): saved \(png.lastPathComponent), \(size), window \(Int(bounds.width))x\(Int(bounds.height)) pt")
            if look.window == .main {
                // Within a few points: macOS can settle a window a few points inside the size it was given.
                if abs(bounds.width - 1440) > 8 || abs(bounds.height - 900) > 40 {
                    print("FAIL  \(name): the main window is \(Int(bounds.width))x\(Int(bounds.height)) pt, not the 1440 by 900 it opens at")
                    failures += 1
                }
                let check = analyze(png)
                if !describe(name, check) { failures += 1 }
                // Needs You opens with the sidebar focused, so its selection must be the accent color: that
                // is the state that hid the icon on 10 Oct. Grey there means the window was not frontmost
                // and the check proved nothing.
                if look.accent && check?.isAccent != true {
                    print("FAIL  \(name): the selection is not in the accent color, so the window was not frontmost. Run it again without touching the Mac.")
                    failures += 1
                }
            }
        }
        quitAll(app)
    }
}
// The development refusal, seen in the real window: the app tries to add the Studio Recordings
// folder (in memory, through the same path Add Folder takes) and must show its alert.
for appearance in appearances {
    let name = "11-refusal-\(appearance)"
    let studio = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/Design Work/Galindo x Lizarde/Studio Recordings "
    // --development: the refusal belongs to a test copy. The live Prakriti owns the studio folder.
    run("/usr/bin/open", ["-n", app.path, "--args", "--sample-data", "--development", "--show=source", "--appearance=" + appearance, "--add-folder=" + studio])
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

// The keys (v2 part M3a), in the same run.
let keyFailures = runKeysCheck(app)
failures += keyFailures
index += 1
print(failures == 0 ? "PASS: every real window drew its selected sidebar row with a visible icon and label, the refusal showed, and every key did what it says"
                    : "FAIL: \(failures) of \(index) captures failed")
finish(failures == 0 ? 0 : 1)
