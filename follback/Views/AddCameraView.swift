import SwiftUI
import SwiftData

struct AddCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var format: FilmFormat = .mm35
    @State private var cameraType: CameraType = .slr
    @State private var fixedFocalLength = ""
    @State private var notes = ""
    @State private var cardAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                detailsCard
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
                            colors: [Color.filmGold.opacity(0.15), Color.filmGold.opacity(0.02)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "camera")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text("New Camera")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
        }
        .frame(maxWidth: .infinity)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : -15)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Camera Details")

            fieldRow(label: "Name") {
                TextField("e.g. Nikon F3", text: $name)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Brand") {
                TextField("e.g. Nikon", text: $brand)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Film Format") {
                Picker("", selection: $format) {
                    ForEach(FilmFormat.allCases, id: \.self) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Color.filmAccent)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Camera Type") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CameraType.allCases, id: \.self) { type in
                            let isSelected = cameraType == type
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    cameraType = type
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } label: {
                                Text(type.displayName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Color.filmBackground : Color.filmSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
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

            fieldRow(label: "Fixed Focal Length (optional)") {
                TextField("e.g. 50mm", text: $fixedFocalLength)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: cardAppeared)
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
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: cardAppeared)
    }

    private var saveButton: some View {
        Button {
            saveCamera()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text("Save Camera")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        name.isEmpty
                        ? AnyShapeStyle(Color.filmTertiary)
                        : AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: name.isEmpty ? .clear : Color.filmAccent.opacity(0.35), radius: 12, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
        .opacity(cardAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: cardAppeared)
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

    private func saveCamera() {
        let camera = Camera(
            name: name,
            brand: brand,
            format: format,
            type: cameraType,
            fixedFocalLength: fixedFocalLength.isEmpty ? nil : fixedFocalLength,
            notes: notes
        )
        modelContext.insert(camera)
        try? modelContext.save()
        dismiss()
    }
}
