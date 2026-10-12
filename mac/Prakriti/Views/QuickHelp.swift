import SwiftUI

/// Quick Help (v2 part M3b, design spec 5.5 and 3.5.0): with Help > Show Quick Help on, a panel at the top
/// of the inspector says what the control under the pointer does, at 15 pt, with "More in Help". It
/// replaces tooltips, which Prakriti never uses (they draw at 11 pt, under the 12 pt floor; START_HERE Mac
/// warning 5). Off by default. A control declares its words with `.quickHelp(_:article:)`.
@MainActor
@Observable
final class QuickHelpModel {
    /// Help > Show Quick Help. Off by default; kept for the next launch.
    var isOn = false
    /// What the pointer is over now, or nil.
    private(set) var text: String?
    private(set) var article: String?

    /// The words stay after the pointer leaves the control, until another control sets its own, so they can
    /// be read while the pointer moves to the panel to click More in Help.
    func show(_ text: String, article: String?) {
        self.text = text
        self.article = article
    }

    /// The panel's words when the pointer is over nothing that explains itself.
    static let idle = "Point at a control to see what it does."
}

private struct QuickHelpModifier: ViewModifier {
    let text: String
    let article: String?
    @Environment(AppModel.self) private var model: AppModel?

    func body(content: Content) -> some View {
        content.onHover { inside in
            guard inside, let model, model.quickHelp.isOn else { return }
            model.quickHelp.show(text, article: article)
        }
    }
}

extension View {
    /// The words Quick Help shows while the pointer is over this view (one or two sentences), and the Help
    /// article "More in Help" opens.
    func quickHelp(_ text: String, article: String? = nil) -> some View {
        modifier(QuickHelpModifier(text: text, article: article))
    }
}

/// The Quick Help panel at the top of the inspector.
struct QuickHelpPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Quick Help").font(AppFont.secondaryEmphasis)
            } icon: {
                Image(systemName: "questionmark.circle").font(AppFont.secondaryEmphasis)
            }
            Text(model.quickHelp.text ?? QuickHelpModel.idle)
                .font(AppFont.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 240, alignment: .leading)
            HStack(spacing: 12) {
                if let article = model.quickHelp.article {
                    Button("More in Help") { model.openHelp(article: article) }
                }
                Spacer()
                Button("Hide Quick Help") { model.quickHelp.isOn = false }
            }
            .font(AppFont.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick Help")
    }
}
