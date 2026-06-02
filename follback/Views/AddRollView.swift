import SwiftUI
import SwiftData

struct AddRollView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Camera.name) var cameras: [Camera]

    @State private var filmName = ""
    @State private var selectedCamera: Camera?
    @State private var capacity = 36
    @State private var iso = 400
    @State private var format: FilmFormat = .mm35
    @State private var evCompensation: Float = 0
    @State private var pushPull: Float = 0
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var showAddCamera = false
    @State private var appeared = false

    private let isoOptions = [100, 200, 400, 800, 1600, 3200]
    private let evOptions: [Float] = [-3, -2, -1, -0.5, 0, 0.5, 1, 2, 3]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                nameCard
                cameraCard
                capacityCard
                filmSettingsCard
                dateCard
                notesCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("New Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(Color.filmText)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveRoll() }
                    .disabled(filmName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(Color.filmAccent)
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showAddCamera) {
            NavigationStack {
                AddCameraView(onSave: { camera in
                    selectedCamera = camera
                })
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
            sectionLabel("Roll Name")
            TextField("e.g. Kodak Portra 400", text: $filmName)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Camera")
            VStack(spacing: 12) {
                Picker("Select camera", selection: $selectedCamera) {
                    Text("None").tag(nil as Camera?)
                    ForEach(cameras) { camera in
                        Text(camera.name).tag(camera as Camera?)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.filmAccent)
                .foregroundColor(Color.filmText)

                Button("Add New Camera...") { showAddCamera = true }
                    .foregroundColor(Color.filmAccent)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.04), value: appeared)
    }

    private var capacityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Capacity")
            Picker("Frames", selection: $capacity) {
                Text("24 frames").tag(24)
                Text("36 frames").tag(36)
            }
            .pickerStyle(.segmented)
            .colorMultiply(Color.filmAccent)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: appeared)
    }

    private var filmSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Film Settings")
            VStack(spacing: 16) {
                Picker("ISO", selection: $iso) {
                    ForEach(isoOptions, id: \.self) { value in
                        Text("ISO \(value)").tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.filmAccent)
                .foregroundColor(Color.filmText)

                Picker("Format", selection: $format) {
                    ForEach(FilmFormat.allCases, id: \.self) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.filmAccent)
                .foregroundColor(Color.filmText)

                Picker("EV Compensation", selection: $evCompensation) {
                    ForEach(evOptions, id: \.self) { val in
                        Text(String(format: "%+.1f", val)).tag(val)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.filmAccent)
                .foregroundColor(Color.filmText)

                Picker("Push / Pull", selection: $pushPull) {
                    ForEach(evOptions, id: \.self) { val in
                        if val == 0 {
                            Text("0 stops").tag(val)
                        } else {
                            Text(String(format: "%+.1f stops", val)).tag(val)
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.filmAccent)
                .foregroundColor(Color.filmText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.12), value: appeared)
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Start Date")
            DatePicker("", selection: $startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .foregroundColor(Color.filmText)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
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
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func saveRoll() {
        let roll = Roll(
            filmName: filmName.trimmingCharacters(in: .whitespaces),
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
