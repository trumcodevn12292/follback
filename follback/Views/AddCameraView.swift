import SwiftUI
import SwiftData

struct AddCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: ((Camera) -> Void)?

    @State private var name = ""
    @State private var brand = ""
    @State private var format: FilmFormat = .mm35
    @State private var type: CameraType = .slr
    @State private var fixedFocalLength: String = ""
    @State private var notes = ""
    @State private var appeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                nameCard
                brandCard
                formatCard
                typeCard
                focalCard
                notesCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("New Camera")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(Color.filmText)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveCamera() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || brand.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(Color.filmAccent)
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Camera Name")
            TextField("e.g. Leica M6", text: $name)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(16)
                .background(cardBackground)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var brandCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Brand")
            TextField("e.g. Leica", text: $brand)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(16)
                .background(cardBackground)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.04), value: appeared)
    }

    private var formatCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Format")
            Picker("Film Format", selection: $format) {
                ForEach(FilmFormat.allCases, id: \.self) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .colorMultiply(Color.filmAccent)
            .padding(16)
            .background(cardBackground)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: appeared)
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Type")
            Picker("Camera Type", selection: $type) {
                ForEach(CameraType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.filmAccent)
            .foregroundColor(Color.filmText)
            .padding(16)
            .background(cardBackground)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)
    }

    private var focalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Fixed Focal Length (optional)")
            TextField("e.g. 50", text: $fixedFocalLength)
                .keyboardType(.numberPad)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(16)
                .background(cardBackground)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.16), value: appeared)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Notes")
            TextEditor(text: $notes)
                .frame(minHeight: 80)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(12)
                .background(cardBackground)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.filmSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.filmBorder, lineWidth: 0.5)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func saveCamera() {
        let focal = Int(fixedFocalLength.trimmingCharacters(in: .whitespaces))
        let camera = Camera(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces),
            format: format,
            type: type,
            fixedFocalLength: focal,
            notes: notes
        )
        modelContext.insert(camera)
        try? modelContext.save()
        onSave?(camera)
        dismiss()
    }
}
