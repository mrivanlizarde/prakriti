import AppKit
import SwiftData
import SwiftUI

/// The welcome window (v2 part M2b; docs/v2/design-spec.md 4.1): five panels at the first launch, and
/// from Help, Welcome to Prakriti. 720 by 600 pt, not resizable, in front of the main window, which stays
/// usable behind it. "1 of 5" in words at the bottom leading edge; Back and Continue at the trailing edge,
/// the last panel's button Start Using Prakriti. Return continues, Command-Left goes back, Escape closes.
/// Everything fits without scrolling at 17 pt, and the window says so in the log when a panel does not.
struct WelcomeWindow: View {
    static let id = "welcome"
    /// The panel's size. The title bar is hidden (no title, its close button kept) and sits above it, so
    /// the window measures 720 by 632 pt in all (measured on macOS 27.2).
    static let size = CGSize(width: 720, height: 600)
    /// The whole window with its hidden title bar's band (measured on macOS 27.2, the real window and a
    /// test window alike).
    static let windowSize = CGSize(width: 720, height: 632)
    static let topPadding: CGFloat = 12
    static let sidePadding: CGFloat = 48
    static let bottomPadding: CGFloat = 26
    /// The least space between the panel and the buttons.
    static let footerGap: CGFloat = 16

    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var panelHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    var body: some View {
        let welcome = model.welcome
        VStack(alignment: .leading, spacing: 0) {
            WelcomePanelView(panel: welcome.current, actions: actions)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0; measure() }
                .id(welcome.current.id)
            Spacer(minLength: Self.footerGap)
            footer
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0; measure() }
        }
        .padding(.top, Self.topPadding)
        .padding(.horizontal, Self.sidePadding)
        .padding(.bottom, Self.bottomPadding)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background {
            // Escape closes the window, as the close button does (docs/v2/design-spec.md 4.1).
            Button("Close") { dismissWindow(id: Self.id) }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .onAppear {
            if model.openMainWindow == nil { model.openMainWindow = { openWindow(id: MainWindow.id) } }
            if model.openHelpWindow == nil { model.openHelpWindow = { openWindow(id: HelpWindow.id) } }
            if !model.welcomeAppeared() { dismissWindow(id: Self.id) }
        }
    }

    /// The space the panel and the buttons need, against the window's height.
    private func measure() {
        guard panelHeight > 0, footerHeight > 0 else { return }
        let needed = Self.topPadding + panelHeight + Self.footerGap + footerHeight + Self.bottomPadding
        model.welcomeMeasured(panel: model.welcome.panel + 1, needed: needed, room: Self.size.height)
    }

    private var footer: some View {
        let welcome = model.welcome
        return HStack(spacing: 12) {
            Text(welcome.position)
                .font(AppFont.secondary)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("Panel \(welcome.panel + 1) of \(welcome.panels.count)")
            Spacer()
            Button("Back") { welcome.goBack() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(welcome.isFirst)
            if welcome.isLast {
                Button("Start Using Prakriti") { start() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue") { welcome.goForward() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }

    /// Start Using Prakriti: the welcome closes and the main window comes forward.
    private func start() {
        openWindow(id: MainWindow.id)
        NSApp.activate()
        dismissWindow(id: Self.id)
    }

    private var actions: WelcomeActions {
        WelcomeActions(
            chooseFolder: { model.chooseFolderForWelcome() },
            turnOnNotifications: { Task { await model.notifier.turnOn() } },
            openHelp: { id in model.openHelp(article: id) })
    }
}

/// What the panel's buttons and links do, handed in so a snapshot can draw a panel without a window.
struct WelcomeActions {
    var chooseFolder: () -> Void = {}
    var turnOnNotifications: () -> Void = {}
    var openHelp: (String?) -> Void = { _ in }
}

/// One panel: its symbol at 48 pt in the accent color, the title at 28 pt semibold, the line at 17 pt
/// secondary, then its rows (a 28 pt symbol beside a 17 pt semibold headline and a 17 pt sentence, read
/// as one paragraph so six rows fit), and a "More in Help" link where the panel has one.
struct WelcomePanelView: View {
    let panel: VisibleWelcomePanel
    var actions = WelcomeActions()
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: panel.symbol)
                    .font(AppFont.welcomeSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(HelpColors.link)
                    .frame(width: 60)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(panel.title)
                        .font(AppFont.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text(panel.line)
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: panel.rows.count > 4 ? 13 : 18) {
                ForEach(panel.rows) { row in
                    WelcomeRowView(row: row, symbol: panel.symbol(for: row), actions: actions)
                }
            }
            if let id = panel.helpArticle, let article = model.help.library.visibleArticle(id: id) {
                Button {
                    actions.openHelp(id)
                } label: {
                    Text("More in Help: \(article.title)")
                        .font(AppFont.body)
                        .foregroundStyle(HelpColors.link)
                }
                .buttonStyle(.plain)
                .padding(.leading, 78)
                .accessibilityHint("Opens the article in Help")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One row. The last panel's rows carry a button and say what it did.
struct WelcomeRowView: View {
    let row: WelcomeRow
    let symbol: String
    var actions = WelcomeActions()
    @Environment(AppModel.self) private var model
    @Query(sort: \Source.addedAt) private var sources: [Source]

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: symbol)
                .font(AppFont.welcomeRowSymbol)
                .foregroundStyle(HelpColors.link)
                .frame(width: 60)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
                if let status {
                    Label {
                        Text(status.text)
                            .font(AppFont.secondary)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        if let symbol = status.symbol {
                            Image(systemName: symbol)
                                .font(AppFont.secondary)
                                .foregroundStyle(status.color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let button {
                Button(button.title, action: button.perform)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The headline and the sentence as one paragraph: the headline semibold, the sentence regular.
    private var paragraph: AttributedString {
        var text = AttributedString()
        if let headline = row.headline {
            var bold = AttributedString(headline + " ")
            bold.font = AppFont.headline
            text += bold
        }
        var sentence = AttributedString(row.sentence)
        sentence.font = AppFont.body
        text += sentence
        return text
    }

    private struct Status {
        let text: String
        var symbol: String?
        var color: Color = .secondary
    }

    /// What the row's button did, or what is true now.
    private var status: Status? {
        switch row.action {
        case .chooseFolder:
            switch model.welcome.folderChoice {
            case .added(let name):
                return Status(text: "Added \(name). It is set to Ask me first.", symbol: "checkmark.circle.fill", color: .green)
            case .alreadyWatched(let name):
                return Status(text: "\(name) is already watched.", symbol: "checkmark.circle.fill", color: .green)
            case .refused(let name, let reason):
                return Status(text: "\(name) was not added. \(reason)", symbol: "exclamationmark.triangle", color: .orange)
            case nil:
                let names = sources.map { $0.name.trimmingCharacters(in: .whitespaces) }
                return Status(text: names.isEmpty ? "No folder is watched yet." : "Watching now: \(StatusSummary.folderPhrase(names)).")
            }
        case .notifications:
            switch model.notifier.permission {
            case .allowed:
                return Status(text: "On.", symbol: "checkmark.circle.fill", color: .green)
            case .denied:
                return Status(text: "Off. Click Open Notification Settings, then turn on Allow notifications.",
                              symbol: "exclamationmark.triangle", color: .orange)
            case .waitingForAnswer, .unknown:
                return nil
            }
        case .openHelp, nil:
            return nil
        }
    }

    private var button: (title: String, perform: () -> Void)? {
        switch row.action {
        case .chooseFolder:
            return ("Choose Folder…", actions.chooseFolder)
        case .notifications:
            switch model.notifier.permission {
            case .allowed: return nil
            case .denied: return ("Open Notification Settings…", actions.turnOnNotifications)
            case .waitingForAnswer, .unknown: return ("Turn On Notifications", actions.turnOnNotifications)
            }
        case .openHelp:
            return ("Open Help", { actions.openHelp(nil) })
        case nil:
            return nil
        }
    }
}
