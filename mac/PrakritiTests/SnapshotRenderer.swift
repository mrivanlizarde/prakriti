import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import Prakriti

/// Draws the main window, with whatever model it is given, into a PNG at the window's real size,
/// light or dark. Used by SnapshotTests (sample data) and PipelineAcceptanceTests (recordings the
/// pipeline really processed). No Screen Recording permission is needed: the window draws itself
/// into a bitmap. Rendering is not the check: a person looks at every PNG.
@MainActor
final class SnapshotRenderer {
    let outputFolder: URL

    init(outputFolder: URL) throws {
        self.outputFolder = outputFolder
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    }

    /// screens/mac/<milestone>/ in the repo (gitignored), from PRAKRITI_SNAPSHOT_MILESTONE.
    static func milestoneFolder(suffix: String? = nil) -> URL {
        let milestone = ProcessInfo.processInfo.environment["PRAKRITI_SNAPSHOT_MILESTONE"] ?? "latest"
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = repo.appending(path: "screens/mac/\(milestone)", directoryHint: .isDirectory)
        return suffix.map { folder.appending(path: $0, directoryHint: .isDirectory) } ?? folder
    }

    static let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]

    func render(model: AppModel, appearance: NSAppearance.Name, name: String) throws {
        let size = MainWindow.size
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.title = "Prakriti"
        window.toolbarStyle = .unified
        let root = MainView()
            .environment(model)
            .modelContainer(model.container)
        let host = NSHostingView(rootView: root)
        host.sceneBridgingOptions = [.toolbars, .title]
        window.contentView = host
        window.setContentSize(size)
        window.alphaValue = 0.01
        // The test window is never frontmost (macOS does not let it take focus), so switches and
        // selected segments draw in their inactive grey. The knob's side still shows the state:
        // right is on.
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }

        // Let SwiftUI lay out, run its queries and settle the split view.
        for _ in 0..<12 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()
        }

        let frameView = window.contentView?.superview ?? host
        try save(composite(frameView: frameView, window: window, model: model), name: name, size: size)

        // A page taller than the window gets a second picture, scrolled to its end, so nothing
        // below the fold goes unlooked-at.
        let sidebarView = firstView(in: frameView, where: { $0.contains("SidebarStyleContext") })
        let scrollers = views(in: frameView, where: { _ in true }).compactMap { $0 as? NSScrollView }.filter { scroll in
            guard let document = scroll.documentView else { return false }
            let inSidebar = sidebarView.map { scroll.isDescendant(of: $0) } ?? false
            return !inSidebar && document.frame.height > scroll.contentView.bounds.height + 20
        }
        // A page more than two windows tall also gets a picture of each screenful between the top
        // and the end ("-p2", "-p3"), because on 10 Oct a recording's page put its Results and its
        // own outputs between the two pictures, where nobody looked.
        if !scrollers.isEmpty {
            func scrollAll(_ fraction: (NSScrollView, CGFloat) -> CGFloat) {
                for scroll in scrollers {
                    guard let document = scroll.documentView else { continue }
                    let end = document.frame.height - scroll.contentView.bounds.height
                    let fromTop = min(end, fraction(scroll, end))
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: document.isFlipped ? fromTop : end - fromTop))
                    scroll.reflectScrolledClipView(scroll.contentView)
                }
                for _ in 0..<6 {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                    host.layoutSubtreeIfNeeded()
                }
            }
            let tallest = scrollers.compactMap { scroll -> CGFloat? in
                guard let document = scroll.documentView else { return nil }
                return (document.frame.height - scroll.contentView.bounds.height) / max(1, scroll.contentView.bounds.height - 60)
            }.max() ?? 0
            let middles = max(0, Int(tallest.rounded(.up)) - 1)
            for page in 0..<middles {
                scrollAll { scroll, _ in CGFloat(page + 1) * (scroll.contentView.bounds.height - 60) }
                try save(composite(frameView: frameView, window: window, model: model), name: name + "-p\(page + 2)", size: size)
            }
            scrollAll { _, end in end }
            try save(composite(frameView: frameView, window: window, model: model), name: name + "-end", size: size)
        }
    }

    private func save(_ rep: NSBitmapImageRep, name: String, size: CGSize) throws {
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: outputFolder.appending(path: name + ".png"))
        XCTAssertEqual(rep.size.width, size.width, accuracy: 1, "\(name) is not at the window's real size")
        XCTAssertEqual(rep.size.height, size.height, accuracy: 1, "\(name) is not at the window's real size")
        XCTAssertGreaterThan(distinctColors(rep), 50, "\(name) looks blank")
    }

    /// Liquid Glass cannot be drawn into a bitmap: the glass sidebar comes out as solid white,
    /// hiding the rows. So the snapshot is composed: the whole window as it draws itself, then the
    /// sidebar column painted with the system window background, then the real sidebar view (the
    /// same SwiftUI rows, fonts and counts) drawn on top, then the title bar controls again. What
    /// the PNG cannot show is the glass material itself; open the app to see that.
    private func composite(frameView: NSView, window: NSWindow, model: AppModel) throws -> NSBitmapImageRep {
        let bounds = frameView.bounds
        let base = try XCTUnwrap(frameView.bitmapImageRepForCachingDisplay(in: bounds))
        frameView.cacheDisplay(in: bounds, to: base)
        guard let sidebar = firstView(in: frameView, where: { $0.contains("SidebarStyleContext") }),
              let baseImage = base.cgImage else { return base }

        let scale = CGFloat(base.pixelsWide) / bounds.width
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = try XCTUnwrap(CGContext(data: nil, width: base.pixelsWide, height: base.pixelsHigh, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(baseImage, in: CGRect(x: 0, y: 0, width: base.pixelsWide, height: base.pixelsHigh))

        let column = sidebar.convert(sidebar.bounds, to: frameView)
        let pixels = { (r: CGRect) in CGRect(x: r.minX * scale, y: r.minY * scale, width: r.width * scale, height: r.height * scale) }
        var background = NSColor.windowBackgroundColor.cgColor
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            background = NSColor.windowBackgroundColor.usingColorSpace(.sRGB)?.cgColor ?? background
        }
        ctx.setFillColor(background)
        ctx.fill(pixels(column))

        // The sidebar rows, drawn by the same Sidebar view in a plain window of the column's size,
        // placed under the title bar.
        let titlebar = firstView(in: frameView, where: { $0 == "NSTitlebarContainerView" })
        let titlebarHeight = titlebar?.frame.height ?? 52
        let rows = try renderStandaloneSidebar(model: model, size: CGSize(width: column.width, height: bounds.height - titlebarHeight),
                                               appearance: window.effectiveAppearance)
        if let image = rows.cgImage {
            ctx.draw(image, in: pixels(CGRect(x: column.minX, y: 0, width: column.width, height: bounds.height - titlebarHeight)))
        }

        // The title bar controls over the sidebar column (window buttons, sidebar button), each
        // drawn on its own so the title bar's background does not cover the column.
        if let titlebar {
            for control in views(in: titlebar, where: { $0.hasPrefix("_NSTheme") || $0 == "NSToolbarPlatterView" }) {
                let rect = control.convert(control.bounds, to: frameView)
                guard rect.maxX <= column.maxX else { continue }
                if let image = try cacheWithVibrancy(control).cgImage { ctx.draw(image, in: pixels(rect)) }
            }
        }
        let out = NSBitmapImageRep(cgImage: try XCTUnwrap(ctx.makeImage()))
        out.size = bounds.size
        return out
    }

    /// Draws a view into a bitmap the way the screen shows it, as closely as a bitmap can. macOS
    /// colors some layers only when it composites the screen (vibrancy), and a bitmap capture skips
    /// that step: sidebar labels use a plus-darker or plus-lighter blend, and symbols use a vibrant
    /// color matrix whose source is only a template. Skipped, labels came out grey, sidebar icons
    /// grey or black, and in light the title bar's sidebar button was an empty white circle. So those
    /// layers are left out of the plain capture and drawn on top: labels with their own blend mode,
    /// sidebar symbols in the accent color and the title bar glyph in the label color, which is what
    /// the frontmost real window shows (measured from scripts/capture-window.swift, 10 Oct).
    private func cacheWithVibrancy(_ view: NSView) throws -> NSBitmapImageRep {
        let vibrant = vibrantLayers(under: view.layer, appearance: view.effectiveAppearance)
        let wasHidden = vibrant.map(\.layer.isHidden)
        vibrant.forEach { $0.layer.isHidden = true }
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        for (item, hidden) in zip(vibrant, wasHidden) { item.layer.isHidden = hidden }
        guard !vibrant.isEmpty, let root = view.layer, let base = rep.cgImage else { return rep }

        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let ctx = try XCTUnwrap(CGContext(data: nil, width: rep.pixelsWide, height: rep.pixelsHigh, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: space, bitmapInfo: info))
        ctx.draw(base, in: CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
        for item in vibrant where !item.layer.isHidden && item.layer.opacity > 0 {
            let layer = item.layer
            var rect = root.convert(layer.bounds, from: layer)
            // The bitmap's origin is bottom left; a flipped layer tree counts from the top.
            if root.contentsAreFlipped() || root.isGeometryFlipped { rect.origin.y = view.bounds.height - rect.maxY }
            let w = Int((rect.width * scale).rounded(.up)), h = Int((rect.height * scale).rounded(.up))
            guard w > 0, h > 0, let piece = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                                     space: space, bitmapInfo: info) else { continue }
            piece.scaleBy(x: scale, y: scale)
            if layer.contentsAreFlipped() {
                piece.translateBy(x: 0, y: rect.height)
                piece.scaleBy(x: 1, y: -1)
            }
            piece.translateBy(x: -layer.bounds.minX, y: -layer.bounds.minY)
            layer.render(in: piece)
            if case .fill(let color) = item.effect {
                piece.setBlendMode(.sourceIn)
                piece.setFillColor(color)
                piece.fill(CGRect(x: layer.bounds.minX, y: layer.bounds.minY, width: rect.width, height: rect.height))
            }
            guard let image = piece.makeImage() else { continue }
            ctx.saveGState()
            switch item.effect {
            case .plusDarker: ctx.setBlendMode(.plusDarker)
            case .plusLighter: ctx.setBlendMode(.plusLighter)
            case .fill: ctx.setBlendMode(.normal)
            }
            ctx.setAlpha(CGFloat(layer.opacity))
            ctx.draw(image, in: CGRect(x: rect.minX * scale, y: rect.minY * scale, width: CGFloat(w), height: CGFloat(h)))
            ctx.restoreGState()
        }
        let out = NSBitmapImageRep(cgImage: try XCTUnwrap(ctx.makeImage()))
        out.size = view.bounds.size
        return out
    }

    private enum VibrancyEffect {
        case plusDarker, plusLighter
        /// The layer's shape, filled with one color.
        case fill(CGColor)
    }

    /// Every layer under `root` that macOS colors at composite time, with how the test draws it.
    private func vibrantLayers(under root: CALayer?, appearance: NSAppearance) -> [(layer: CALayer, effect: VibrancyEffect)] {
        guard let root else { return [] }
        var label = NSColor.labelColor.cgColor, accent = NSColor.controlAccentColor.cgColor
        appearance.performAsCurrentDrawingAppearance {
            label = NSColor.labelColor.usingColorSpace(.sRGB)?.cgColor ?? label
            accent = NSColor.controlAccentColor.usingColorSpace(.sRGB)?.cgColor ?? accent
        }
        func isVibrantMatrix(_ filter: Any?) -> Bool {
            guard let filter = filter as? NSObject, !(filter is NSString) else { return false }
            return String(describing: filter).hasPrefix("vibrantColorMatrix")
        }
        var found: [(CALayer, VibrancyEffect)] = []
        func walk(_ layer: CALayer) {
            if let name = layer.compositingFilter as? String, name == "plusD" || name == "plusL" {
                found.append((layer, name == "plusD" ? .plusDarker : .plusLighter))
            } else if isVibrantMatrix(layer.compositingFilter) {
                found.append((layer, .fill(accent)))
            } else if (layer.filters ?? []).contains(where: isVibrantMatrix) {
                found.append((layer, .fill(label)))
            } else {
                for sub in layer.sublayers ?? [] { walk(sub) }
            }
        }
        walk(root)
        return found
    }

    private func renderStandaloneSidebar(model: AppModel, size: CGSize, appearance: NSAppearance) throws -> NSBitmapImageRep {
        let window = FrontmostWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        let host = NSHostingView(rootView: Sidebar(selection: .constant(model.selection))
            .environment(\.controlActiveState, .key)
            .environment(model)
            .modelContainer(model.container))
        window.contentView = host
        window.setContentSize(size)
        window.alphaValue = 0.01
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }
        for _ in 0..<8 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()
        }
        // The real window opens with the sidebar focused, so macOS draws its selection in the accent
        // color with the row's icon and text in white. The test draws that same state: the window
        // reports itself frontmost and the sidebar's list takes the focus, so SwiftUI draws the row
        // emphasized. Reason: a grey stand-in selection once hid a real bug (an accent icon on the
        // accent selection vanished in the app while every snapshot looked fine, 10 Oct).
        if let list = views(in: host, where: { _ in true }).first(where: { $0 is NSTableView }) {
            window.makeFirstResponder(list)
        }
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        for row in views(in: host, where: { _ in true }).compactMap({ $0 as? NSTableRowView }) where row.isSelected {
            row.isEmphasized = true
        }
        for _ in 0..<4 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            host.layoutSubtreeIfNeeded()
        }
        // The highlight itself is a material, which draws as solid black in a bitmap. Swap it for a
        // plain fill of the accent color, which is what the frontmost real window paints: measured
        // 10 Oct, its selection is (35, 55, 198) in light and (68, 92, 236) in dark, the accent color
        // exactly, not the darker selectedContentBackgroundColor.
        var selectionColor = NSColor.controlAccentColor
        appearance.performAsCurrentDrawingAppearance {
            selectionColor = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? selectionColor
        }
        var boxes: [NSBox] = []
        for effect in views(in: host, where: { $0 == "NSVisualEffectView" }) where effect.superview.map({ String(describing: type(of: $0)).contains("RowView") }) == true {
            let box = NSBox(frame: effect.frame)
            box.boxType = .custom
            box.borderWidth = 0
            box.cornerRadius = 10
            box.fillColor = selectionColor
            effect.isHidden = true
            effect.superview?.addSubview(box, positioned: .below, relativeTo: nil)
            boxes.append(box)
        }
        host.layoutSubtreeIfNeeded()
        let rep = try cacheWithVibrancy(host)
        for box in boxes {
            assertSelectedRowIsReadable(rep, row: box.convert(box.bounds, to: host), fill: selectionColor, in: host)
        }
        return rep
    }

    /// The check that would have caught the 10 Oct bug: on the selected row, the icon and the label
    /// must stand out from the selection color. Counts the pixels in the row's icon slot (its first
    /// 16%) and its label slot (20% to 60%) that differ clearly from the fill.
    private func assertSelectedRowIsReadable(_ rep: NSBitmapImageRep, row: NSRect, fill: NSColor, in view: NSView) {
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        guard let f = fill.usingColorSpace(.sRGB) else { return XCTFail("selection color has no sRGB form") }
        func differing(fromX x0: CGFloat, toX x1: CGFloat) -> Int {
            var n = 0
            let top = view.isFlipped ? row.minY : view.bounds.height - row.maxY
            for y in Int((top + row.height * 0.2) * scale)..<Int((top + row.height * 0.8) * scale) {
                for x in Int(x0 * scale)..<Int(x1 * scale) {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    let d = abs(c.redComponent - f.redComponent) + abs(c.greenComponent - f.greenComponent) + abs(c.blueComponent - f.blueComponent)
                    if d * 255 > 90 { n += 1 }
                }
            }
            return n
        }
        let icon = differing(fromX: row.minX, toX: row.minX + row.width * 0.16)
        let label = differing(fromX: row.minX + row.width * 0.2, toX: row.minX + row.width * 0.6)
        XCTAssertGreaterThan(icon, 150, "The selected sidebar row's icon is invisible against the selection (\(icon) px stand out)")
        XCTAssertGreaterThan(label, 150, "The selected sidebar row's label is invisible against the selection (\(label) px stand out)")
    }

    private func views(in view: NSView, where matches: (String) -> Bool) -> [NSView] {
        var found: [NSView] = matches(String(describing: type(of: view))) ? [view] : []
        for child in view.subviews { found += views(in: child, where: matches) }
        return found
    }

    private func firstView(in view: NSView, where matches: (String) -> Bool) -> NSView? {
        if matches(String(describing: type(of: view))) { return view }
        for child in view.subviews {
            if let found = firstView(in: child, where: matches) { return found }
        }
        return nil
    }

    private func distinctColors(_ rep: NSBitmapImageRep) -> Int {
        var seen = Set<UInt32>()
        let step = 7
        for y in stride(from: 0, to: rep.pixelsHigh, by: step) {
            for x in stride(from: 0, to: rep.pixelsWide, by: step) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let v = (UInt32(c.redComponent * 255) << 16) | (UInt32(c.greenComponent * 255) << 8) | UInt32(c.blueComponent * 255)
                seen.insert(v)
                if seen.count > 200 { return seen.count }
            }
        }
        return seen.count
    }
}

/// A window that reports itself frontmost, so the sidebar draws its selection the way the real,
/// frontmost window does (accent fill, white icon and text). Test windows never really get focus.
private final class FrontmostWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
}
