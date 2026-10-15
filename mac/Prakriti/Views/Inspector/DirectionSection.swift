import SwiftUI

/// Direction for one recording (v2 part M9c, design spec 3.5.3 and 3.7), at the top of the inspector's Direction tab (v2 part
/// M9d): the field for Ivan's own words, the preset capsules, Pace and Length, and every field
/// the direction was read as, shown back as chips he can remove before anything is planned or made. The rules read as he types
/// (no model); words they cannot read are read by the "Planning the edit" model when he plans. Nothing changes until Plan Again
/// or Make Again.
struct DirectionSection: View {
    @Bindable var recording: Recording
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        let direction = recording.direction
        let plan = model.editPlan(for: recording)
        let cached = plan?.direction?.reading
        let reading = Direction.read(direction, house: model.settings.houseStyle,
                                     model: cached.flatMap { r in r.byModel.map { ($0, r.modelBy ?? "", r.modelReadFor ?? "") } })
        Section {
            // A system text field that grows to four lines and more, with the design spec's example as its prompt.
            TextField("Direction", text: $text,
                      prompt: Text("Describe the edit you want. For example: more energetic, faster cuts, keep the story about the first retreat."),
                      axis: .vertical)
                .lineLimit(4...10)
                .font(AppFont.body)
                .labelsHidden()
                .accessibilityLabel("Direction")
            .onAppear {
                if !loaded { text = direction.prompt; loaded = true }
            }
            .onChange(of: recording.id) { text = recording.direction.prompt }
            .onChange(of: text) {
                var changed = recording.direction
                guard changed.prompt != text else { return }
                changed.prompt = text
                changed.removed = []
                model.setDirection(changed, for: recording)
            }

            FlowLayout(spacing: 8) {
                ForEach(DirectionPreset.allCases) { preset in
                    Toggle(preset.title, isOn: Binding(get: { direction.presets.contains(preset) }, set: { _ in
                        var changed = recording.direction
                        changed.toggle(preset)
                        model.setDirection(changed, for: recording)
                    }))
                    .toggleStyle(.button)
                    .buttonBorderShape(.capsule)
                    .font(AppFont.body)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Presets")

            Picker("Pace", selection: Binding(get: { direction.pace }, set: { pace in
                var changed = recording.direction
                changed.pace = pace
                changed.removed = []
                model.setDirection(changed, for: recording)
            })) {
                Text("As in House Style (\(model.settings.houseStyle.pace.title))").tag(Pace?.none)
                ForEach(Pace.allCases) { Text($0.title).tag(Optional($0)) }
            }
            .font(AppFont.body)
            Picker("Length", selection: Binding(get: { direction.length }, set: { length in
                var changed = recording.direction
                changed.length = length
                changed.removed = []
                model.setDirection(changed, for: recording)
            })) {
                ForEach(LengthChoice.allCases) { Text($0.title).tag($0) }
            }
            .font(AppFont.body)

            if !reading.chips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Read as").font(AppFont.headline)
                    FlowLayout(spacing: 8) {
                        ForEach(reading.chips) { chip in
                            DirectionChipView(chip: chip) {
                                var changed = recording.direction
                                if !changed.removed.contains(chip.id) { changed.removed.append(chip.id) }
                                model.setDirection(changed, for: recording)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            if !reading.unread.isEmpty && reading.byModel == nil {
                RowNote("When you plan, \(model.settings.provider[.planning]?.title ?? "the planning model") reads the words no rule reads: \u{201C}\(reading.unread.joined(separator: " "))\u{201D}.")
            } else if let by = reading.modelBy {
                RowNote("Your own words were read by \(by).")
            }
            ForEach(reading.said, id: \.self) { line in
                Label {
                    Text(line).font(AppFont.body).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle").font(AppFont.body)
                }
                .accessibilityElement(children: .combine)
            }
            if !direction.isEmpty || !direction.removed.isEmpty {
                HStack(spacing: 10) {
                    Button("Clear Direction") {
                        text = ""
                        model.setDirection(RecordingDirection(), for: recording)
                    }
                    .quickHelp("Goes back to the House Style in Settings for this recording.", article: "editorial-direction")
                }
            }
        } header: {
            SectionHeader("Direction")
        }
    }
}

/// One field of a direction read back, with a button that removes it.
struct DirectionChipView: View {
    let chip: DirectionChip
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(chip.text).font(AppFont.secondary)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill").font(AppFont.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(chip.text)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
        .accessibilityElement(children: .contain)
    }
}

/// Lays its views out in rows, wrapping to the next row when one is full (the preset capsules and the chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // An unbounded or missing width (a measuring pass) lays everything in one row and asks for no more than that.
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .greatestFiniteMagnitude
        let rows = rows(width: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let widest = rows.map { row in
            row.indices.reduce(0) { $0 + subviews[$1].sizeThatFits(.unspecified).width } + spacing * CGFloat(max(0, row.indices.count - 1))
        }.max() ?? 0
        return CGSize(width: min(width, widest), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [(indices: [Int], height: CGFloat)] {
        var rows: [(indices: [Int], height: CGFloat)] = []
        var current: [Int] = [], x: CGFloat = 0, height: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width.isFinite && width < .greatestFiniteMagnitude ? width : nil, height: nil))
            if !current.isEmpty && x + size.width > width {
                rows.append((current, height))
                current = []
                x = 0
                height = 0
            }
            current.append(index)
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !current.isEmpty { rows.append((current, height)) }
        return rows
    }
}
