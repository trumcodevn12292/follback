import SwiftUI
import SwiftData

// MARK: - Development Recipe presets

enum DevRecipePresets {
    static let developers: [String] = [
        "Kodak D-76", "Kodak HC-110", "Kodak XTOL",
        "Ilford ID-11", "Ilford DD-X", "Ilford Microphen",
        "Rodinal / Adonal", "Cinestill DF96", "Caffenol"
    ]

    static let dilutions: [String] = [
        "Stock", "1+1", "1+3", "1+25", "1+31", "1+50", "1+100"
    ]

    /// Format a number of seconds as "m:ss".
    static func timeLabel(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Editor

struct DevRecipeEditorView: View {
    @Bindable var roll: Roll
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var developer = ""
    @State private var dilution = ""
    @State private var tempC: Double = 20
    @State private var minutes = 7
    @State private var seconds = 0
    @State private var agitation = ""
    @State private var pushPull: Float = 0
    @State private var devNotes = ""
    @State private var hasDevelopedDate = false
    @State private var developedDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    developerSection
                    dilutionSection
                    tempTimeSection
                    pushPullSection
                    agitationSection
                    developedDateSection
                    notesSection
                    saveButton
                    if roll.hasDevRecipe {
                        clearButton
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Development Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.filmAccent)
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Sections

    private var developerSection: some View {
        section("DEVELOPER") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("e.g. Kodak D-76", text: $developer)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmText)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.filmSurfaceSecondary)
                    )
                chips(DevRecipePresets.developers, selected: developer) { developer = $0 }
            }
        }
    }

    private var dilutionSection: some View {
        section("DILUTION") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("e.g. 1+1", text: $dilution)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmText)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.filmSurfaceSecondary)
                    )
                chips(DevRecipePresets.dilutions, selected: dilution) { dilution = $0 }
            }
        }
    }

    private var tempTimeSection: some View {
        section("TEMPERATURE & TIME") {
            VStack(spacing: 0) {
                HStack {
                    Text("Temperature")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    Text(String(format: "%.1f °C", tempC))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.filmAccent)
                    Stepper("", value: $tempC, in: 10...35, step: 0.5)
                        .labelsHidden()
                }
                .padding(16)

                Divider().background(Color.filmBorder.opacity(0.3))

                HStack {
                    Text("Time")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    Picker("", selection: $minutes) {
                        ForEach(0...60, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.filmAccent)
                    Picker("", selection: $seconds) {
                        ForEach(0...59, id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.filmAccent)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
    }

    private var pushPullSection: some View {
        section("PUSH / PULL") {
            HStack {
                Text("Stops")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmText)
                Spacer()
                Text(pushPullLabel(pushPull))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.filmAccent)
                Stepper("", value: $pushPull, in: -3...3, step: 1)
                    .labelsHidden()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
    }

    private var agitationSection: some View {
        section("AGITATION") {
            TextField("e.g. 30s initial, then 3 inversions / 30s", text: $agitation)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.filmText)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.filmSurface)
                )
        }
    }

    private var developedDateSection: some View {
        section("DEVELOPED") {
            VStack(spacing: 0) {
                Toggle(isOn: $hasDevelopedDate) {
                    Text("Set developed date")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                }
                .tint(Color.filmAccent)
                .padding(16)

                if hasDevelopedDate {
                    Divider().background(Color.filmBorder.opacity(0.3))
                    DatePicker("Date", selection: $developedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.filmAccent)
                        .foregroundColor(Color.filmText)
                        .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
            )
        }
    }

    private var notesSection: some View {
        section("RECIPE NOTES") {
            TextEditor(text: $devNotes)
                .font(.system(size: 15))
                .foregroundColor(Color.filmText)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save Recipe")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.filmText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmAccent)
                )
        }
        .buttonStyle(.plain)
    }

    private var clearButton: some View {
        Button(action: clear) {
            Text("Clear Recipe")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.filmError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.filmError.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)
            content()
        }
    }

    private func chips(_ items: [String], selected: String, action: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isSelected = item.lowercased() == selected.lowercased()
                    Button {
                        action(item)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(item)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isSelected ? Color.filmBackground : Color.filmText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.filmAccent : Color.filmSurface)
                            )
                            .overlay(
                                Capsule().stroke(Color.filmBorder, lineWidth: isSelected ? 0 : 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func pushPullLabel(_ value: Float) -> String {
        if value == 0 { return L("Box speed") }
        let sign = value > 0 ? "+" : ""
        let unit = abs(value) == 1 ? L("stop") : L("stops")
        return "\(sign)\(Int(value)) \(unit)"
    }

    private func load() {
        developer = roll.devDeveloper ?? ""
        dilution = roll.devDilution ?? ""
        tempC = roll.devTempC ?? 20
        if let total = roll.devTimeSeconds {
            minutes = total / 60
            seconds = total % 60
        }
        agitation = roll.devAgitation ?? ""
        pushPull = roll.pushPull
        devNotes = roll.devNotes ?? ""
        if let date = roll.developedDate {
            hasDevelopedDate = true
            developedDate = date
        }
    }

    private func save() {
        roll.devDeveloper = developer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : developer
        roll.devDilution = dilution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dilution
        roll.devTempC = tempC
        let total = minutes * 60 + seconds
        roll.devTimeSeconds = total > 0 ? total : nil
        roll.devAgitation = agitation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : agitation
        roll.pushPull = pushPull
        roll.devNotes = devNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : devNotes
        roll.developedDate = hasDevelopedDate ? developedDate : nil
        roll.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func clear() {
        roll.devDeveloper = nil
        roll.devDilution = nil
        roll.devTempC = nil
        roll.devTimeSeconds = nil
        roll.devAgitation = nil
        roll.devNotes = nil
        roll.developedDate = nil
        roll.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
    }
}
