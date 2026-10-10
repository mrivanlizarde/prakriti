import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import Prakriti

/// Draws every screen, with fixture data, in light and dark, at the window's real size, to
/// screens/mac/<milestone>/ in the repo (gitignored). No Screen Recording permission is needed:
/// each window draws itself into a bitmap. Then a person LOOKS at the PNGs: rendering is not the
/// check, looking is.
///
///   cd ~/Code/prakriti/mac && make snapshots MILESTONE=m1
@MainActor
final class SnapshotTests: XCTestCase {
    private var outputFolder: URL {
        let milestone = ProcessInfo.processInfo.environment["PRAKRITI_SNAPSHOT_MILESTONE"] ?? "latest"
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return repo.appending(path: "screens/mac/\(milestone)", directoryHint: .isDirectory)
    }

    private let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]

    func testRenderEveryScreen() throws {
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        var written: [String] = []

        for (index, item) in SidebarItem.allCases.enumerated() {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                model.selection = item
                let name = String(format: "%02d-%@-%@", index + 1, item.rawValue, scheme)
                try render(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }

        // The recording page, for the 13 Sep talk and for the silent 14 Sep class.
        for (slug, title) in [("recording-ready", "Talk with Gabriel"), ("recording-silent", "Class")] {
            for (scheme, appearance) in appearances {
                let model = Fixtures.model()
                let recordings = try model.context.fetch(FetchDescriptor<Recording>())
                let recording = try XCTUnwrap(recordings.first { $0.title == title && ($0.status == .readyForYourYes || $0.status == .needsADecision) })
                model.open(recording)
                let name = "08-\(slug)-\(scheme)"
                try render(model: model, appearance: appearance, name: name)
                written.append(name)
            }
        }

        // Today with nothing waiting, and nothing set up.
        for (scheme, appearance) in appearances {
            let model = Fixtures.model(empty: true)
            model.selection = .today
            let name = "09-today-empty-\(scheme)"
            try render(model: model, appearance: appearance, name: name)
            written.append(name)
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: outputFolder.path).filter { $0.hasSuffix(".png") }
        print("Snapshots written to \(outputFolder.path): \(written.count) screens, \(files.count) pictures")
        XCTAssertEqual(written.count, SidebarItem.allCases.count * 2 + 6)
    }

    private func render(model: AppModel, appearance: NSAppearance.Name, name: String) throws {
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
        if !scrollers.isEmpty {
            for scroll in scrollers {
                guard let document = scroll.documentView else { continue }
                let end = document.isFlipped ? document.frame.height - scroll.contentView.bounds.height : 0
                scroll.contentView.scroll(to: NSPoint(x: 0, y: end))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            for _ in 0..<6 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                host.layoutSubtreeIfNeeded()
            }
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
                guard rect.maxX <= column.maxX, let piece = control.bitmapImageRepForCachingDisplay(in: control.bounds) else { continue }
                control.cacheDisplay(in: control.bounds, to: piece)
                if let image = piece.cgImage { ctx.draw(image, in: pixels(rect)) }
            }
        }
        let out = NSBitmapImageRep(cgImage: try XCTUnwrap(ctx.makeImage()))
        out.size = bounds.size
        return out
    }

    private func renderStandaloneSidebar(model: AppModel, size: CGSize, appearance: NSAppearance) throws -> NSBitmapImageRep {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        let host = NSHostingView(rootView: Sidebar(selection: .constant(model.selection))
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
        // The selected row's highlight is a material, which also draws as solid black in a bitmap.
        // Swap it for a plain fill of the system's selected-row color.
        var selectionColor = NSColor.unemphasizedSelectedContentBackgroundColor
        appearance.performAsCurrentDrawingAppearance {
            selectionColor = NSColor.unemphasizedSelectedContentBackgroundColor.usingColorSpace(.sRGB) ?? selectionColor
        }
        for effect in views(in: host, where: { $0 == "NSVisualEffectView" }) where effect.superview.map({ String(describing: type(of: $0)).contains("RowView") }) == true {
            let box = NSBox(frame: effect.frame)
            box.boxType = .custom
            box.borderWidth = 0
            box.cornerRadius = 10
            box.fillColor = selectionColor
            effect.isHidden = true
            effect.superview?.addSubview(box, positioned: .below, relativeTo: nil)
        }
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep
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
