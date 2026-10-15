import SwiftUI

/// Settings, House Style (v2 part M9a, design spec 3.13; research-edit-engine.md 2.3 to 2.6): the style every edited video
/// is planned with, its pace, the punch-ins, Teaching and the room at the end. Each line says what the setting does in
/// numbers, read from `Style`, so the pane cannot describe something the plan does not do. A change is used the next time
/// the edit is planned (Plan the Edit, Make Again, or a new recording); nothing is made again on its own (PLAN rule 2.1.7).
struct HouseStylePane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        let house = settings.houseStyle
        let style = Style.make(house)
        Form {
            Section {
                Picker("Style", selection: $settings.houseStyle.style) {
                    ForEach(StyleName.allCases) { name in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.title).font(AppFont.body)
                            Text(name.line).font(AppFont.secondary).foregroundStyle(.appSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                        .tag(name)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                SectionHeader("Style")
            } footer: {
                RowNote(Self.numbersLine(style))
            }

            Section {
                LabeledContent {
                    Picker("Pace", selection: $settings.houseStyle.pace) {
                        ForEach(Pace.allCases) { pace in Text(pace.title).tag(pace) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 300)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pace").font(AppFont.body)
                        Text("Brisk makes the pauses a fifth shorter and the changes a quarter more; Relaxed makes the pauses a quarter longer and the changes a fifth fewer.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LabeledContent {
                    Picker("Punch-ins", selection: $settings.houseStyle.punchIns) {
                        ForEach(PunchLevel.allCases) { level in Text(level.title).tag(level) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 300)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Punch-ins").font(AppFont.body)
                        Text(Self.punchLine(house.punchIns, style: style))
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.houseStyle.teaching) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Teaching").font(AppFont.body)
                        Text("Keeps demonstrations whole and wide: punch-ins only at cuts, no slow push-in, and the whole picture wherever no face is seen.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.houseStyle.endingRoom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Room at the end").font(AppFont.body)
                        Text("The speaking ends 5 seconds before the last frame, so YouTube's end screen covers no words. The last frame is held, without sound.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: {
                SectionHeader("Pace and Zooms")
            }

            Section {
                // The opening line (v2 part M9d), first, because the title follows it.
                Toggle(isOn: $settings.houseStyle.openingLine) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open on the strongest line").font(AppFont.body)
                        Text(Self.openingLine(Style.make(settings.houseStyle.with(openingLine: true))))
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.houseStyle.titleOnScreen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Title at the start").font(AppFont.body)
                        Text("The recording's title, as you set it in Info, for 2 seconds as the talk begins (after the opening line), beside the teacher and never over a face. A recording with no title shows none.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.houseStyle.namesOnScreen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Teacher's name").font(AppFont.body)
                        Text("Once, the first time the teacher is seen after the title: their name and \u{201C}Teacher\u{201D} near the bottom, on the side away from their face, for about 4 seconds. Only for a teacher you named who is included in the video.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Picker(selection: $settings.houseStyle.keyPhrases) {
                    ForEach(TextLevel.allCases) { Text($0.title).tag($0) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Key phrases").font(AppFont.body)
                        Text(Self.keyPhraseLine(settings.houseStyle))
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Toggle(isOn: $settings.houseStyle.termCards) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Terms").font(AppFont.body)
                        Text("A Sanskrit term the talk explains, spelled as the Yoga Marga word list spells it, once, near the bottom on the side away from the teacher.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LabeledContent {
                    Text(TypeFace.familyName).font(AppFont.body)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Typeface").font(AppFont.body)
                        Text("Yoga Marga's own, under an open font licence that allows it in videos. White, with a soft shadow, no box behind it.")
                            .font(AppFont.secondary).foregroundStyle(.appSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: {
                SectionHeader("Text on Screen")
            } footer: {
                RowNote("Used the next time an edit is planned: Plan the Edit, Make Again, or a new recording. Videos already made stay as they are.")
            }
        }
        .formStyle(.grouped)
    }

    /// The style's numbers in one sentence: "Pauses inside a sentence over 0.40 s become 0.18 s, ...".
    static func numbersLine(_ style: Style) -> String {
        func s(_ x: Double) -> String { String(format: "%.2f s", x) }
        func n(_ x: Double) -> String { x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x) }
        var line = "\(style.name.title) at \(style.pace.title) pace: pauses inside a sentence over \(s(style.insideTrigger)) become \(s(style.insideTarget)), "
            + "between sentences over \(s(style.sentenceTrigger)) become \(s(style.sentenceTarget)). "
            + "About \(n(style.changesPerMinute.lowerBound)) to \(n(style.changesPerMinute.upperBound)) changes of picture a minute"
        line += style.openingChanges > 0 ? ", \(style.openingChanges) in the first 30 seconds." : "."
        return line
    }

    /// The opening line in numbers for the chosen style (v2 part M9d).
    static func openingLine(_ style: Style) -> String {
        guard let range = style.opening else {
            return "\(style.name.title) opens on the talk itself, so there is no opening line in this style."
        }
        return String(format: "The video opens on the talk's strongest line, %.0f to %.0f seconds in the speaker's own words, then the title, then the talk from its start. The line is chosen from the parts of the talk the planning model marks, and checked word for word.",
                      range.lowerBound, range.upperBound)
    }

    /// What Key phrases does at its setting, in numbers (v2 part M9d).
    static func keyPhraseLine(_ house: HouseStyle) -> String {
        let style = Style.make(house)
        guard let every = style.keyPhraseEvery else { return "None." }
        return String(format: "2 to 6 of the speaker's own words, on the side away from the teacher, at most one every %.0f to %.0f seconds. Subtle is the style's own rate, Bold is Energetic's.",
                      every.lowerBound, every.upperBound)
    }

    /// What the chosen punch-ins do with this style, in numbers.
    static func punchLine(_ level: PunchLevel, style: Style) -> String {
        let tight = style.punchScales.dropFirst().map { String(format: "%.2f", $0) }
        switch level {
        case .off:
            return "None: the whole picture throughout."
        default:
            var line = tight.count > 1
                ? "The whole picture, then \(tight.joined(separator: " and ")) in turn"
                : "The whole picture and \(tight.first ?? "1.00") in turn"
            line += style.punchOnlyWhereCutsJump ? ", changing only at cuts that would jump." : ", centred on the teacher's face."
            if let push = style.pushIn {
                line += String(format: " A slow push-in to %.2f over %.0f s, at most once every %.0f s.", push.to, push.seconds, push.every)
            }
            return line + " Never more than 1.15 on a 1080p recording."
        }
    }
}
