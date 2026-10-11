import SwiftUI

/// Ivan's interface type scale: the system font, 17 pt body, nothing under 12 pt. macOS text styles
/// run small (body 13 pt, footnote and caption 10 pt), so views never use them: every font comes
/// from here. A unit test reads the view sources and fails on any other font, and checks that
/// every size below is 12 pt or more.
enum AppFont {
    static let pageTitle = Font.system(size: 28, weight: .semibold)
    static let sectionTitle = Font.system(size: 21, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17)
    static let secondary = Font.system(size: 15)
    static let secondaryEmphasis = Font.system(size: 15, weight: .semibold)
    static let label = Font.system(size: 13, weight: .semibold)
    /// Paths and timecodes: monospaced digits, never smaller than secondary.
    static let numbers = Font.system(size: 15).monospacedDigit()
    static let path = Font.system(size: 15, design: .monospaced)
    /// The welcome window (v2 part M2b, docs/v2/design-spec.md 4.1): each panel's symbol at 48 pt, and
    /// each row's symbol at 28 pt beside 17 pt text.
    static let welcomeSymbol = Font.system(size: 48)
    static let welcomeRowSymbol = Font.system(size: 28)

    /// Every size used above, for the test that enforces the 12 pt floor.
    static let sizes: [CGFloat] = [28, 21, 17, 17, 15, 15, 13, 15, 15, 48, 28]
}

enum Metrics {
    static let pagePadding: CGFloat = 28
    static let rowSpacing: CGFloat = 6
    static let symbolWidth: CGFloat = 24
}
