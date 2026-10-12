import AppKit
import SwiftUI

/// The colors text is drawn in (v2 part M3a, docs/v2/design-spec.md 6.2 and 6.6). Every one measures
/// 4.5 to 1 or more against the backgrounds it sits on, in light and dark and with Increase Contrast
/// (WCAG's formula, as Accessibility Inspector uses it; `AppColorTests` measures each pair).
///
/// Two of the system's own colors fall short and are replaced here, measured on macOS 27.2 on Sun 11 Oct:
/// - the secondary label color in light is black at 50 percent, 3.95 to 1 on the white window, so
///   secondary text is black at 58 percent in light (5.1 to 1). In dark the system's own measures 5.89.
/// - the accent as text in dark, #4459E8, is 3.05 to 1 on the dark window (design spec C7), so text and
///   links use #7D8BFF in dark (5.56). The accent asset keeps #4459E8 for fills (the selected sidebar
///   row, prominent buttons), where white on it measures 5.47.
/// - red text for a problem is #B3261E in light (systemRed measures 3.57 on white) and #FF6B63 in dark
///   (systemRed measures 4.29 on the dark grouped background).
enum AppColor {
    static let accentTextNS = NSColor(name: "prakriti.accentText") { appearance in
        switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
        case .darkAqua: NSColor(srgbRed: 0x7D / 255.0, green: 0x8B / 255.0, blue: 0xFF / 255.0, alpha: 1)
        case .accessibilityHighContrastDarkAqua: NSColor(srgbRed: 0x9A / 255.0, green: 0xA5 / 255.0, blue: 0xFF / 255.0, alpha: 1)
        default: NSColor(srgbRed: 0x23 / 255.0, green: 0x37 / 255.0, blue: 0xC6 / 255.0, alpha: 1)
        }
    }

    static let secondaryTextNS = NSColor(name: "prakriti.secondaryText") { appearance in
        switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
        case .darkAqua, .accessibilityHighContrastDarkAqua: NSColor.secondaryLabelColor
        case .accessibilityHighContrastAqua: NSColor(white: 0, alpha: 0.7)
        default: NSColor(white: 0, alpha: 0.58)
        }
    }

    static let problemTextNS = NSColor(name: "prakriti.problemText") { appearance in
        switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua]) {
        case .darkAqua, .accessibilityHighContrastDarkAqua: NSColor(srgbRed: 0xFF / 255.0, green: 0x6B / 255.0, blue: 0x63 / 255.0, alpha: 1)
        default: NSColor(srgbRed: 0xB3 / 255.0, green: 0x26 / 255.0, blue: 0x1E / 255.0, alpha: 1)
        }
    }

    /// Behind the sentence playing in the Viewer's transcript (v2 part M3b, design spec 3.4.4): the accent at
    /// 12 percent over the text background, mixed here into one solid color so its contrast can be measured.
    static let playingHighlightNS = NSColor(name: "prakriti.playingHighlight") { appearance in
        var mixed = NSColor.white
        appearance.performAsCurrentDrawingAppearance {
            let base = NSColor.textBackgroundColor.usingColorSpace(.sRGB) ?? .white
            let accent = (NSColor(named: "AccentColor") ?? .controlAccentColor).usingColorSpace(.sRGB) ?? .blue
            mixed = base.blended(withFraction: 0.12, of: accent) ?? base
        }
        return mixed
    }

    /// Text, links and symbols that carry meaning, in the accent.
    static let accentText = Color(nsColor: accentTextNS)
    /// Secondary text, drawn through `.appSecondary` (below).
    static let secondaryText = Color(nsColor: secondaryTextNS)
    /// A problem said in words (a time that cannot work, a refused cut).
    static let problemText = Color(nsColor: problemTextNS)

    /// One text color on one background, for the contrast test.
    struct Pair {
        let name: String
        let text: NSColor
        let background: NSColor
    }

    /// Every text color Prakriti draws and the backgrounds it is drawn on. The accent fill is the
    /// app's own asset; white text sits on it in the selected sidebar row and prominent buttons.
    static var pairs: [Pair] {
        let accentFill = NSColor(named: "AccentColor") ?? .controlAccentColor
        var pairs: [Pair] = []
        for (backgroundName, background) in [("window", NSColor.windowBackgroundColor), ("control", .controlBackgroundColor),
                                             ("under page", .underPageBackgroundColor), ("text", .textBackgroundColor)] {
            pairs.append(Pair(name: "primary text on the \(backgroundName) background", text: .labelColor, background: background))
            pairs.append(Pair(name: "secondary text on the \(backgroundName) background", text: secondaryTextNS, background: background))
            pairs.append(Pair(name: "accent text on the \(backgroundName) background", text: accentTextNS, background: background))
            pairs.append(Pair(name: "problem text on the \(backgroundName) background", text: problemTextNS, background: background))
        }
        pairs.append(Pair(name: "white text on the accent fill", text: .white, background: accentFill))
        // The Viewer's transcript (v2 part M3b): the sentence playing, its kept and its removed words.
        pairs.append(Pair(name: "primary text on the playing highlight", text: .labelColor, background: playingHighlightNS))
        pairs.append(Pair(name: "secondary text on the playing highlight", text: secondaryTextNS, background: playingHighlightNS))
        return pairs
    }

    /// WCAG's contrast ratio of `text` drawn over `background`, in an appearance. A translucent text color
    /// is first laid over its background, as the screen does.
    static func contrast(_ pair: Pair, in appearance: NSAppearance) -> Double {
        var ratio = 0.0
        appearance.performAsCurrentDrawingAppearance {
            guard let text = pair.text.usingColorSpace(.sRGB), let back = pair.background.usingColorSpace(.sRGB) else { return }
            let a = text.alphaComponent
            let laid = [text.redComponent * a + back.redComponent * (1 - a), text.greenComponent * a + back.greenComponent * (1 - a),
                        text.blueComponent * a + back.blueComponent * (1 - a)]
            func luminance(_ c: [CGFloat]) -> Double {
                let linear = c.map { v -> Double in
                    let v = Double(v)
                    return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
                }
                return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
            }
            let l1 = luminance(laid), l2 = luminance([back.redComponent, back.greenComponent, back.blueComponent])
            ratio = (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
        }
        return ratio
    }
}

/// Secondary text everywhere in the app: `AppColor.secondaryText`, except on a selected, emphasized row
/// (the sidebar's, the list's), where the system draws text white on the accent and secondary text must
/// follow it. Written `.foregroundStyle(.appSecondary)`; a test fails on `.foregroundStyle(.appSecondary)`.
/// Reason: the system's secondary label color measures 3.95 to 1 on the white window (measured Sun 11
/// Oct), under the 4.5 text needs; and replacing the hierarchy for a whole window (`foregroundStyle(_:_:)`)
/// was tried and turned every bordered button and quaternary fill dark (real window, the same day).
struct AppSecondaryStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.backgroundProminence == .increased ? Color.white.opacity(0.85) : AppColor.secondaryText
    }
}

extension ShapeStyle where Self == AppSecondaryStyle {
    static var appSecondary: AppSecondaryStyle { AppSecondaryStyle() }
}
