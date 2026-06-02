import SwiftUI
import SwiftData
import PhotosUI
import Photos

struct FrameEditorView: View {
    @Bindable var roll: Roll
    var frame: Frame?
    var frameNumber: Int?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedAperture: Aperture?
    @State private var selectedShutter: ShutterSpeed?
    @State private var focusDistance = ""
    @State private var flashUsed = false
    @State private var locationName = ""
    @State private var notes = ""
    @State private var previewImage: UIImage?
    @State private var photoAuthStatus = PHPhotoLibrary.authorizationStatus()
    @State private var appeared = false

    private var currentNumber: Int {
        frame?.number ?? frameNumber ?? 1
    }

    init(roll: Roll, frame: Frame? = nil, frameNumber: Int? = nil) {
        self.roll = roll
        self.frame = frame
        self.frameNumber = frameNumber
        if let existing = frame {
            _selectedAperture = State(initialValue: existing.aperture.flatMap { Aperture(rawValue: $0) })
            _selectedShutter = State(initialValue: existing.shutter)
            _focusDistance = State(initialValue: existing.focusDistance ?? "")
            _flashUsed = State(initialValue: existing.flashUsed)
            _locationName = State(initialValue: existing.locationName ?? "")
            _notes = State(initialValue: existing.notes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    photoSection
                    exposureSection
                    locationSection
                    notesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Frame \(currentNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.filmText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFrame() }
                        .foregroundColor(Color.filmAccent)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.previewImage = image
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Photo")

            if photoAuthStatus == .authorized || photoAuthStatus == .limited {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    photoPreview
                }
                .buttonStyle(.plain)
            } else if photoAuthStatus == .denied || photoAuthStatus == .restricted {
                photoPlaceholder(icon: "lock.circle", text: "Photo library access denied")
            } else {
                Button { requestPhotoAccess() } label: {
                    photoPlaceholder(icon: "photo.badge.plus", text: "Tap to allow photo access")
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var photoPreview: some View {
        Group {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if let assetID = frame?.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                photoPlaceholder(icon: "photo.badge.plus", text: "Tap to select photo")
            }
        }
    }

    private func photoPlaceholder(icon: String, text: String) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.filmSurfaceSecondary)
            .frame(height: 260)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(Color.filmTertiary)
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.filmBorder, lineWidth: 0.5)
            )
    }

    private var exposureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Exposure")

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aperture")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                    DialPicker(items: Aperture.allCases, selected: $selectedAperture, display: { $0.displayName })
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Shutter Speed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                    DialPicker(items: ShutterSpeed.allCases, selected: $selectedShutter, display: { $0.displayName })
                }

                HStack {
                    Text("Focus distance")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    TextField("e.g. 3m", text: $focusDistance)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Color.filmSecondary)
                        .frame(width: 120)
                }
                .padding(.vertical, 4)

                HStack {
                    Text("Flash used")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    Toggle("", isOn: $flashUsed)
                        .labelsHidden()
                        .tint(Color.filmAccent)
                }
                .padding(.vertical, 4)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Location")

            TextField("Location name", text: $locationName)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Notes")

            TextEditor(text: $notes)
                .frame(minHeight: 120)
                .font(.system(size: 16))
                .foregroundColor(Color.filmText)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
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
        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
