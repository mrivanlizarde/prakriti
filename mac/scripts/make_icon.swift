// Draws Prakriti's app icon: the front door's mark (an ultramarine dot on cool stone, from
// web/public/assets/favicon.svg) on the macOS icon grid. Usage: swift make_icon.swift <outdir>
import AppKit
import CoreGraphics

let out = CommandLine.arguments[1]
func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Big Sur grid: 824/1024 body, 100/1024 margin, corner radius 185/1024.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let r = s * 185 / 1024
    let path = CGPath(roundedRect: body, cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(path); ctx.setFillColor(rgb(0xF3F3F0)); ctx.fillPath()
    ctx.addPath(path); ctx.setStrokeColor(rgb(0xB8BAB3)); ctx.setLineWidth(max(1, s / 512)); ctx.strokePath()
    let dot = body.width * 8.5 / 32 * 2  // favicon: r 8.5 on a 32 grid
    ctx.setFillColor(rgb(0x2337C6))
    ctx.fillEllipse(in: CGRect(x: s / 2 - dot / 2, y: s / 2 - dot / 2, width: dot, height: dot))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try! draw(px).write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let json = try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["version": 1, "author": "xcode"]], options: [.prettyPrinted, .sortedKeys])
try! json.write(to: URL(fileURLWithPath: out).appendingPathComponent("Contents.json"))
print("wrote \(images.count) icons")
