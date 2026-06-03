import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct FrameEditorView: View {
    @Bindable var roll: Roll
    var frame: Frame?
    let currentNumber: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedAperture: Aperture?
    @State private var selectedShutter: ShutterSpeed?
    @State private var focusDistance = ""
    @State private var flashUsed = false
    @State private var locationName = ""
    @State private var notes = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    @State private var cardAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                photoSection
                exposureCard
                detailsCard
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
            loadExistingData()
            requestPhotoAccess()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardAppeared = true
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        previewImage = uiImage
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
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
                Text("#\(currentNumber)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Color.filmAccent)
            }
            Text(frame == nil ? "New Frame" : "Edit Frame")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
            Text(roll.filmName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : -15)
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Photo")

            if let preview = previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16))
                    Text(previewImage == nil ? "Choose Photo" : "Change Photo")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color.filmAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.filmAccent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.filmAccent.opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: cardAppeared)
    }

    private var exposureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Exposure")

            VStack(alignment: .leading, spacing: 8) {
                Text("Aperture")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.filmTertiary)
                DialPicker(items: Aperture.allCases, selected: $selectedAperture) { $0.displayName }
            }

            Divider().background(Color.filmBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Shutter Speed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.filmTertiary)
                DialPicker(items: ShutterSpeed.allCases, selected: $selectedShutter) { $0.rawValue }
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: cardAppeared)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Details")

            fieldRow(label: "Focus Distance") {
                TextField("e.g. 1.5m", text: $focusDistance)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundColor(flashUsed ? Color.filmAccent : Color.filmTertiary)
                    Text("Flash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.filmText)
                }
                Spacer()
                Toggle("", isOn: $flashUsed)
                    .labelsHidden()
                    .tint(Color.filmAccent)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Location") {
                TextField("Where was this taken?", text: $locationName)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Notes") {
                TextEditor(text: $notes)
                    .font(.system(size: 15))
                    .foregroundColor(Color.filmText)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: cardAppeared)
    }

    private var saveButton: some View {
        Button {
            saveFrame()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text("Save Frame")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(Color.filmAccent)
                    .shadow(color: Color.filmAccent.opacity(0.25), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .opacity(cardAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: cardAppeared)
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

    private func loadExistingData() {
        guard let frame = frame else { return }
        if let ap = frame.aperture { selectedAperture = Aperture(rawValue: ap) }
        if let sh = frame.shutterSpeed { selectedShutter = ShutterSpeed(rawValue: sh) }
        focusDistance = frame.focusDistance ?? ""
        flashUsed = frame.flashUsed
        locationName = frame.locationName ?? ""
        notes = frame.notes
    }

    private func requestPhotoAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.photoAuthStatus = status
            }
        }
    }

    private func saveFrame() {
        let target: Frame
        if let existing = frame {
            target = existing
        } else {
            target = Frame(number: currentNumber)
            modelContext.insert(target)
            target.roll = roll
        }

        if let image = previewImage,
           let data = image.jpegData(compressionQuality: 0.9) {
            let filename = "\(roll.id.uuidString)_frame_\(currentNumber).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try? data.write(to: url)
            target.photoAssetID = filename
        }

        target.aperture = selectedAperture?.rawValue
        target.shutterSpeed = selectedShutter?.rawValue
        target.focusDistance = focusDistance.isEmpty ? nil : focusDistance
        target.flashUsed = flashUsed
        target.locationName = locationName.isEmpty ? nil : locationName
        target.notes = notes
        target.capturedAt = Date()

        roll.updatedAt = Date()
        roll.checkAutoComplete()
        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
