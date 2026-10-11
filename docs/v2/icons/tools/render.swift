// Rasterizes with AppKit, the same code path the app uses to draw these images.
//
//   swift render.swift svg <in.svg> <out.png> <px> [background #RRGGBB] [tint #RRGGBB]
//       Draws an SVG at px x px. With a tint, the image is drawn as a template image is drawn
//       (its alpha filled with the tint), which is how the menu bar draws Prakriti's glyph.
//   swift render.swift app <path.app> <out.png> <px>
//       Draws an app's icon as Finder and the Dock get it from the system (NSWorkspace), with the
//       system's margin and Liquid Glass rendering.
//   swift render.swift bar <glyph.svg>... <out.png>
//       A 24 pt menu bar at 2x, light above dark: the glyphs, then system SF Symbols for weight.
import AppKit

func color(_ hex: String) -> NSColor {
    let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    let v = UInt32(h, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func bitmap(_ w: Int, _ h: Int, _ draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func tinted(_ img: NSImage, _ c: NSColor, _ size: NSSize) -> NSImage {
    let out = NSImage(size: size)
    out.lockFocus()
    img.draw(in: NSRect(origin: .zero, size: size))
    c.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let a = CommandLine.arguments
switch a[1] {
case "svg":
    guard let img = NSImage(contentsOfFile: a[2]) else { fatalError("cannot read \(a[2])") }
    let px = Int(a[4])!
    let rect = NSRect(x: 0, y: 0, width: px, height: px)
    save(bitmap(px, px) {
        if a.count > 5, a[5] != "-" { color(a[5]).setFill(); rect.fill() }
        if a.count > 6 { tinted(img, color(a[6]), rect.size).draw(in: rect) } else { img.draw(in: rect) }
    }, a[3])
case "app":
    let img = NSWorkspace.shared.icon(forFile: a[2])
    let px = Int(a[4])!
    save(bitmap(px, px) { img.draw(in: NSRect(x: 0, y: 0, width: px, height: px)) }, a[3])
case "bar":
    let glyphs = a[2..<(a.count - 1)].map { p -> NSImage in
        guard let i = NSImage(contentsOfFile: p) else { fatalError("cannot read \(p)") }
        return i
    }
    let W: CGFloat = 600, H: CGFloat = 24, scale: CGFloat = 2
    let rep = bitmap(Int(W * scale), Int(H * 2 * scale)) {
        NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
        for (row, dark) in [(1, false), (0, true)] {
            let y0 = CGFloat(row) * H
            (dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
            NSRect(x: 0, y: y0, width: W, height: H).fill()
            let fg: NSColor = dark ? .white : .black
            var x: CGFloat = 12
            for g in glyphs {
                tinted(g, fg, NSSize(width: 18, height: 18)).draw(in: NSRect(x: x, y: y0 + 3, width: 18, height: 18))
                x += 32
            }
            x += 6
            // Point size 15 approximates the menu bar's symbol size [unverified: the exact size macOS uses].
            let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            for n in ["circle", "circle.dotted", "wifi", "battery.75percent", "magnifyingglass", "switch.2", "moon.fill"] {
                guard let s = NSImage(systemSymbolName: n, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { continue }
                tinted(s, fg, s.size).draw(in: NSRect(x: x, y: y0 + (H - s.size.height) / 2, width: s.size.width, height: s.size.height))
                x += s.size.width + 14
            }
            let t = NSAttributedString(string: "Sat 10 Oct  21:58",
                                       attributes: [.font: NSFont.menuBarFont(ofSize: 0), .foregroundColor: fg])
            t.draw(at: NSPoint(x: x, y: y0 + (H - t.size().height) / 2))
        }
    }
    save(rep, a[a.count - 1])
default:
    fatalError("unknown command \(a[1])")
}
