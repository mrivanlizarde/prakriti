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
