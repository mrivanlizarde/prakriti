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
//   cd ~/Code/prakriti/mac && swift scripts/capture-window.swift --help build/Build/Products/Debug/Prakriti.app ../screens/mac/v2-m2a/real
//
// The app opens with --sample-data: the same sample recordings as the snapshots, in memory only,
// so nothing is saved and Ivan's store is never opened. Each launch takes the screen's focus for a
// few seconds (the window must be frontmost for macOS to draw the selection in the accent color).
// Needs no Screen Recording permission on this Mac: `screencapture -l` captures one window.
import AppKit
import CoreGraphics
import Foundation

let screens = ["today", "recordings", "sources", "outputs", "models", "activity", "settings"]
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
                                         bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
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
    exit(cut ? 0 : 1)
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
    guard let bundle = Bundle(url: app) else { print("FAIL  cannot open \(app.path)"); exit(1) }
    let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
    guard let bar = list.first(where: { ($0[kCGWindowName as String] as? String) == "Menubar" && ($0[kCGWindowOwnerName as String] as? String) == "Window Server" }),
          let barNumber = bar[kCGWindowNumber as String] as? Int,
          let barBounds = (bar[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0) }) else {
        print("FAIL  no menu bar window found"); exit(1)
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
    guard let first = capture() else { print("FAIL  the menu bar could not be captured (screencapture)"); exit(1) }
    let scale = Int((Double(first.height) / barBounds.height).rounded())
    let side = 18 * scale
    // Each glyph's coverage at the capture's scale.
    var glyphs: [(name: String, alpha: [Float])] = []
    for name in names {
        guard let image = bundle.image(forResource: name) else { print("FAIL  \(name) is not in \(app.lastPathComponent)"); exit(1) }
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
        exit(1)
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
    exit(animatedRight ? 0 : 1)
}
// Prakriti Help (v2 part M2a): the REAL Help window, opened on its own with sample data
// (`--sample-data --show=help`) at three articles and at a search, in light and dark, each captured with
// `screencapture -l`; then the Help menu's own search handler, run through the debug switch
// `--debug-help-search` for three words, must list the expected article first. Writes
// acceptance-help.txt in the folder above the pictures. Help shows no recording, so no picture of anyone
// is made.
//   cd ~/Code/prakriti/mac && make accept-help MILESTONE=v2-m2a
if args.first == "--help", args.count == 3 {
    let app = URL(fileURLWithPath: args[1]).standardizedFileURL
    let out = URL(fileURLWithPath: args[2]).standardizedFileURL
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    var report: [String] = ["Prakriti Help, real window and Help menu search (v2 part M2a)", "App: \(app.path)", ""]
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
    say(failures == 0 ? "PASS: Help opened alone at every article and search, light and dark, and the Help menu's search put the expected article first"
                      : "FAIL: \(failures) check(s) failed")
    let file = out.deletingLastPathComponent().appending(path: "acceptance-help.txt")
    try? (report.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    print("      wrote \(file.path)")
    exit(failures == 0 ? 0 : 1)
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
