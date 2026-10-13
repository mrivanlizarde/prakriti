import AppKit
import SwiftData
import SwiftUI

/// The grid (Command-1, the default): cards 240 to 360 pt wide with 20 pt between them, in sections
/// with 21 pt headings (design spec 3.1). Click selects (Command-click adds or takes away), a
/// double-click or Return opens, the arrow keys move the selection, Control-click opens the card's menu.
struct BrowserGrid: View {
    let sections: [LibrarySection]
    let matches: [UUID: LibrarySearch.Match]
    @Environment(AppModel.self) private var model
    @FocusState private var focused: Bool

    static let minimumCard: CGFloat = 240
    static let maximumCard: CGFloat = 360
    static let spacing: CGFloat = 20
    static let margin: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.minimumCard, maximum: Self.maximumCard), spacing: Self.spacing, alignment: .top)],
                          alignment: .leading, spacing: 28) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.recordings) { recording in
                                RecordingCard(recording: recording, isSelected: model.selectedRecordings.contains(recording.id),
                                              match: matches[recording.id])
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { model.open(recording) }
                                    .simultaneousGesture(TapGesture().onEnded { select(recording) })
                                    .contextMenu { RecordingMenu(recording: recording) }
                            }
                        } header: {
                            if let title = section.title {
                                Text(title)
                                    .font(AppFont.sectionTitle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                                    .accessibilityAddTraits(.isHeader)
                            }
                        }
                    }
                }
                .padding(Self.margin)
            }
            // Focusable once something is selected, so at launch the sidebar keeps the focus (its selection drawn
            // in the accent, START_HERE Mac warning 7) and a click on a card brings the keys here.
            .focusable(!model.selectedRecordings.isEmpty)
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress(.return) {
                model.openSelected()
                return .handled
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                move(press.key, columns: Self.columns(for: geometry.size.width))
                return .handled
            }
            // Back from a recording's page, or anything already selected: the keys go to the grid, so
            // Return opens and the arrows move from that recording (Finder's browser does the same).
            .onAppear { if !model.selectedRecordings.isEmpty { focused = true } }
        }
    }

    /// How many cards fit across, the way the adaptive grid lays them out.
    static func columns(for width: CGFloat) -> Int {
        max(1, Int((width - 2 * margin + spacing) / (minimumCard + spacing)))
    }

    private func select(_ recording: Recording) {
        focused = true
        if NSEvent.modifierFlags.contains(.command) {
            if model.selectedRecordings.contains(recording.id) {
                model.selectedRecordings.remove(recording.id)
            } else {
                model.selectedRecordings.insert(recording.id)
            }
        } else {
            model.selectedRecordings = [recording.id]
        }
    }

    /// Moves the selection one card left or right, or one row up or down, in the order the cards are drawn.
    private func move(_ key: KeyEquivalent, columns: Int) {
        let order = sections.flatMap(\.recordings).map(\.id)
        guard !order.isEmpty else { return }
        let current = order.firstIndex { model.selectedRecordings.contains($0) }
        let next: Int
        if let current {
            switch key {
            case .leftArrow: next = current - 1
            case .rightArrow: next = current + 1
            case .upArrow: next = current - columns
            default: next = current + columns
            }
        } else {
            next = 0
        }
        model.selectedRecordings = [order[min(max(next, 0), order.count - 1)]]
    }
}

/// One recording as a card (design spec 3.1.1): a neutral tile with its date and the symbol of its kind
/// (no frame is shown until faces can be checked, design spec 3.1.2 rule 3), its status in symbol and
/// words, its length, its title at 17 pt semibold and the day and time it was recorded. During a search,
/// the sentences that matched, each opening the recording at that moment.
struct RecordingCard: View {
    let recording: Recording
    let isSelected: Bool
    var match: LibrarySearch.Match?
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeutralTile(recording: recording)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    StatusCapsule(status: recording.status, progress: model.runner.progress(for: recording)).padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    if let duration = recording.duration {
                        Capsule()
                            .fill(.background)
                            .overlay(Text(Format.timecode(duration)).font(AppFont.label).monospacedDigit())
                            .frame(width: 64, height: 24)
                            .padding(8)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .padding(-4)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.cardTitle)
                    .font(AppFont.headline)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Format.cardDate(recording.sessionDate))
                    .font(AppFont.secondary)
                    .foregroundStyle(.appSecondary)
                // Who was seen (v2 part M6a, design spec 3.1.1); hidden until faces were looked for.
                if let faces = recording.faces {
                    PeopleLine(faces: faces)
                        .padding(.top, 2)
                }
            }
            if let match, !match.said.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(match.said, id: \.self) { said in
                        Button { model.open(recording, at: said.time) } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(Format.timecode(said.time))
                                    .font(AppFont.numbers)
                                    .foregroundStyle(AppColor.accentText)
                                Text(said.sentence)
                                    .font(AppFont.secondary)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Said at \(Format.timecode(said.time)): \(said.sentence). Opens the recording there.")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// "Sun 13 Sep, Talk with Gabriel, 15 minutes 48 seconds, Waiting for your yes" (design spec 6.6).
    private var accessibilityLine: String {
        var parts = [Format.dayLabel(recording.sessionDate), recording.cardTitle]
        if let duration = recording.duration { parts.append(Format.spokenLength(duration)) }
        parts.append(recording.status.title)
        if let faces = recording.faces { parts.append(faces.line) }
        if let progress = model.runner.progress(for: recording) { parts.append(ProgressWords.spoken(progress)) }
        return parts.joined(separator: ", ")
    }
}

/// The tile a recording shows until a safe frame can be chosen: the system's quaternary fill, the
/// recording's date at 21 pt semibold and the symbol of its kind (design spec 3.1.2 rule 3).
struct NeutralTile: View {
    let recording: Recording
    var compact = false

    var body: some View {
        RoundedRectangle(cornerRadius: compact ? 6 : 10)
            .fill(.quaternary)
            .overlay {
                if compact {
                    Image(systemName: recording.kind.tileSymbol)
                        .font(AppFont.body)
                        .foregroundStyle(.appSecondary)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: recording.kind.tileSymbol)
                            .font(AppFont.welcomeRowSymbol)
                            .foregroundStyle(.appSecondary)
                        Text(Format.dayLabel(recording.sessionDate))
                            .font(AppFont.sectionTitle)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .accessibilityHidden(true)
    }
}

/// A status on a card: its symbol and its words at 13 pt semibold, never color alone. While the recording is
/// made, a ring and the percent take the symbol's place: "Working 64%" (v2 part M4a, design spec 3.6.1).
struct StatusCapsule: View {
    let status: RecordingStatus
    var progress: ProgressSnapshot?

    var body: some View {
        HStack(spacing: 5) {
            if let progress, status == .working {
                ProgressRing(fraction: progress.overall, size: 14, lineWidth: 2.5)
                Text(progress.isPaused ? "Paused" : status.title)
                    .foregroundStyle(.primary)
                Text("\(progress.percent)%")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: status.symbol)
                    .foregroundStyle(status.tint)
                Text(status.title)
                    .foregroundStyle(.primary)
            }
        }
        .font(AppFont.label)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.background, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// A recording's menu, the same for a card, a list row and the Recording menu's subjects
/// (design spec 3.1.1, three groups): open and show; make and mark; remove.
struct RecordingMenu: View {
    let recording: Recording
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Open") { model.open(recording) }
        Button("Show Original in Finder") { model.showOriginalInFinder(recording) }
        Button("Show Outputs in Finder") { model.showOutputsInFinder(recording) }
            .disabled(recording.outputFolder == nil)
        Divider()
        if let start = model.startTitle(recording) {
            Button(start) { model.makeOutputs(recording) }
        }
        Button("Make Again…") { model.ask(.makeAgain, for: recording) }
            .disabled(!model.canMakeAgain(recording))
        Menu("Mark As") {
            ForEach(RecordingKind.choices, id: \.self) { kind in
                Toggle(kind.choiceTitle, isOn: Binding(get: { recording.kind == kind || (kind == .unknown && recording.kind == .test) },
                                                       set: { if $0 { model.setKind(kind, for: recording) } }))
            }
        }
        .disabled(recording.status == .working || recording.status == .skipped)
        Divider()
        Button("Remove from Library…") { model.ask(.removeFromLibrary, for: recording) }
            .disabled(!model.canRemoveFromLibrary(recording))
    }
}
