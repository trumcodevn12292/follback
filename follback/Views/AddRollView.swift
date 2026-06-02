import SwiftUI
import SwiftData

struct AddRollView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Camera.name) var cameras: [Camera]

    @State private var filmName = ""
    @State private var selectedCamera: Camera?
    @State private var capacity = 36
    @State private var iso = "400"
    @State private var format: FilmFormat = .mm35
    @State private var evCompensation: Double = 0
    @State private var pushPull: Double = 0
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var cardAppeared = false

    let isoOptions = ["50", "100", "200", "400", "800", "1600", "3200"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                filmInfoCard
                cameraSection
                exposureCard
                notesCard
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 40)
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardAppeared = true
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.filmAccent.opacity(0.15), Color.filmAccent.opacity(0.02)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "film")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text("New Roll")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
        }
        .frame(maxWidth: .infinity)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : -15)
    }

    private var filmInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Film Details")

            fieldRow(label: "Film Stock") {
                TextField("e.g. Portra 400", text: $filmName)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Format") {
                Picker("", selection: $format) {
                    ForEach(FilmFormat.allCases, id: \.self) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Color.filmAccent)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Capacity") {
                HStack(spacing: 10) {
                    capacityButton(24)
                    capacityButton(36)
                }
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "ISO") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(isoOptions, id: \.self) { option in
                            let isSelected = iso == option
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    iso = option
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } label: {
                                Text(option)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .monospaced))
                                    .foregroundColor(isSelected ? Color.filmBackground : Color.filmSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(
                                                isSelected
                                                ? AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color.filmSurfaceSecondary)
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : Color.filmBorder, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Date") {
                DatePicker("", selection: $startDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color.filmAccent)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: cardAppeared)
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Camera")

            if cameras.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                        .font(.system(size: 16))
                        .foregroundColor(Color.filmTertiary)
                    Text("Add a camera first")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cameras) { camera in
                            let isSelected = selectedCamera?.id == camera.id
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedCamera = isSelected ? nil : camera
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                    Text(camera.name)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(isSelected ? Color.filmBackground : Color.filmText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected
                                            ? AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                                            : AnyShapeStyle(Color.filmSurface)
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : Color.filmBorder, lineWidth: 0.5)
                                )
                                .shadow(color: isSelected ? Color.filmAccent.opacity(0.2) : .clear, radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: cardAppeared)
    }

    private var exposureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Exposure Adjustments")

            VStack(spacing: 14) {
                HStack {
                    Text("EV Compensation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                    Spacer()
                    Text(String(format: "%+.1f", evCompensation))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.filmAccent)
                }
                Slider(value: $evCompensation, in: -3...3, step: 0.5)
                    .tint(Color.filmAccent)
            }

            Divider().background(Color.filmBorder)

            VStack(spacing: 14) {
                HStack {
                    Text("Push/Pull")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                    Spacer()
                    Text(String(format: "%+.1f", pushPull))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.filmGold)
                }
                Slider(value: $pushPull, in: -3...3, step: 0.5)
                    .tint(Color.filmGold)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: cardAppeared)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Notes")
            TextEditor(text: $notes)
                .font(.system(size: 15))
                .foregroundColor(Color.filmText)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(4)
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: cardAppeared)
    }

    private var saveButton: some View {
        Button {
            saveRoll()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text("Save Roll")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        filmName.isEmpty
                        ? AnyShapeStyle(Color.filmTertiary)
                        : AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: filmName.isEmpty ? .clear : Color.filmAccent.opacity(0.35), radius: 12, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .disabled(filmName.isEmpty)
        .opacity(cardAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: cardAppeared)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
            content()
        }
    }

    private func capacityButton(_ value: Int) -> some View {
        let isSelected = capacity == value
        return Button {
            withAnimation(.spring(response: 0.25)) {
                capacity = value
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            Text("\(value)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? Color.filmBackground : Color.filmSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.filmSurfaceSecondary)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.clear : Color.filmBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func saveRoll() {
        let roll = Roll(
            filmName: filmName,
            camera: selectedCamera,
            capacity: capacity,
            iso: iso,
            format: format,
            evCompensation: evCompensation,
            pushPull: pushPull,
            startDate: startDate,
            notes: notes
        )
        modelContext.insert(roll)
        try? modelContext.save()
        dismiss()
    }
}
