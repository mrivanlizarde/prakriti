import AppKit
import SwiftUI

/// Colors for Help's text. Links use the accent in light; in dark, a lighter blue, because the dark
/// accent (#4459E8) measures 3.05 to 1 on the dark window, under the 4.5 text needs, and #7D8BFF
/// measures 5.56 (docs/v2/design-spec.md 6.2, C7).
enum HelpColors {
    static let link = AppColor.accentText
}

/// One article, drawn from its blocks with Ivan's type scale: the title at 28 pt, section headings at
/// 21, body at 17, never under 12 (docs/v2/design-spec.md 5.2). At most 680 pt wide, about 70
/// characters at 17 pt, centered on the window's background. Not a web view: the same fonts, colors
/// and snapshot tests as the rest of the app.
struct HelpArticleView: View {
    let article: HelpArticle
    let blocks: [HelpBlock]
    let related: [HelpArticle]
    let onShowMe: (HelpPlace) -> Void
    let onOpenArticle: (String) -> Void

    static let maxWidth: CGFloat = 680

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    HelpBlockView(block: block, onShowMe: onShowMe)
                }
                if !related.isEmpty {
                    Divider().padding(.top, 14)
                    Text("Related")
                        .font(AppFont.sectionTitle)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(related) { other in
                            Button(other.title) { onOpenArticle(other.id) }
                                .buttonStyle(.link)
                                .font(AppFont.body)
                                .foregroundStyle(HelpColors.link)
                        }
                    }
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: Self.maxWidth, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .tint(HelpColors.link)
        .id(article.id)
    }
}

/// One block. Lists draw their items with this same view, so a list inside a list works.
struct HelpBlockView: View {
    let block: HelpBlock
    let onShowMe: (HelpPlace) -> Void

    var body: some View {
        switch block {
        case .heading(let level, let runs):
            Text(Self.attributed(runs))
                .font(level == 1 ? AppFont.pageTitle : level == 2 ? AppFont.sectionTitle : AppFont.headline)
                .padding(.top, level == 1 ? 0 : level == 2 ? 12 : 4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let runs, let callout, let showMe):
            VStack(alignment: .leading, spacing: 10) {
                if !runs.isEmpty {
                    if let callout {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: callout.symbol)
                                .font(AppFont.body)
                                .foregroundStyle(.appSecondary)
                                .accessibilityHidden(true)
                            paragraphText(runs)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        paragraphText(runs)
                    }
                }
                ForEach(Array(showMe.enumerated()), id: \.offset) { _, link in
                    Button {
                        onShowMe(link.place)
                    } label: {
                        Label(link.title, systemImage: Self.showMeSymbol)
                            .font(AppFont.body)
                    }
                }
            }
        case .list(let ordered, let start, let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { number, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(ordered ? "\(start + number)." : "\u{2022}")
                            .font(AppFont.body)
                            .monospacedDigit()
                            .foregroundStyle(.appSecondary)
                            .frame(minWidth: 22, alignment: .trailing)
                            .accessibilityHidden(!ordered)
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(item.enumerated()), id: \.offset) { _, inner in
                                HelpBlockView(block: inner, onShowMe: onShowMe)
                            }
                        }
                    }
                }
            }
        case .code(let code):
            Text(code)
                .font(AppFont.path)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        case .rule:
            Divider()
        }
    }

    /// The symbol on a Show Me button. Checked to exist by the Help test.
    static let showMeSymbol = "arrow.forward.circle"

    private func paragraphText(_ runs: [HelpRun]) -> some View {
        Text(Self.attributed(runs))
            .font(AppFont.body)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Bold, italics and code as the text's own presentation intents, and a link to another article
    /// as a `prakriti-help://` link the window handles itself.
    static func attributed(_ runs: [HelpRun]) -> AttributedString {
        var out = AttributedString()
        for run in runs {
            var piece = AttributedString(run.text)
            var intent: InlinePresentationIntent = []
            if run.strong { intent.insert(.stronglyEmphasized) }
            if run.emphasis { intent.insert(.emphasized) }
            if run.code { intent.insert(.code) }
            if !intent.isEmpty { piece.inlinePresentationIntent = intent }
            if let id = run.articleLink, let url = URL(string: "prakriti-help://" + id) {
                piece.link = url
                piece.foregroundColor = HelpColors.link
            }
            out += piece
        }
        return out
    }
}
