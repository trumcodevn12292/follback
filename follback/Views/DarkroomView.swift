import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos

struct DarkroomView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFilter: FilmFilter = .none
    @State private var intensity: Double = 1.0
    @State private var contrast: Double = 1.0
    @State private var brightness: Double = 0.0
    @State private var processedImage: UIImage?
    @State private var showSaveSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    previewImage

                    filterPresets

                    sliderSection("Intensity", value: $intensity, range: 0...1.5)
                    sliderSection("Contrast", value: $contrast, range: 0.5...2.0)
                    sliderSection("Brightness", value: $brightness, range: -0.5...0.5)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Darkroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.filmText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveImage() }
                        .foregroundColor(Color.filmAccent)
                        .fontWeight(.semibold)
                }
            }
            .overlay {
                if showSaveSuccess {
                    saveSuccessToast
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .onChange(of: selectedFilter) { _, _ in applyFilter() }
        .onChange(of: intensity) { _, _ in applyFilter() }
        .onChange(of: contrast) { _, _ in applyFilter() }
        .onChange(of: brightness) { _, _ in applyFilter() }
        .onAppear { applyFilter() }
    }

    private var previewImage: some View {
        Group {
            if let processed = processedImage {
                Image(uiImage: processed)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            }
        }
        .frame(maxHeight: 400)
    }

    private var filterPresets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Film Presets")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilmFilter.allCases, id: \.self) { filter in
                        filterButton(filter)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func filterButton(_ filter: FilmFilter) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedFilter = filter
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedFilter == filter ? Color.filmAccent.opacity(0.12) : Color.filmSurface)
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedFilter == filter ? Color.filmAccent : Color.filmBorder, lineWidth: selectedFilter == filter ? 1.5 : 0.5)
                        )

                    Text(filter.icon)
                        .font(.system(size: 28))
                }
                Text(filter.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(selectedFilter == filter ? Color.filmAccent : Color.filmSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func sliderSection(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)
                    .textCase(.uppercase)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.filmAccent)
            }
            Slider(value: value, in: range, step: 0.01)
                .tint(Color.filmAccent)
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

    private var saveSuccessToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.filmSuccess)
                Text("Saved to Photos")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color.filmText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.filmSurface)
                    .overlay(Capsule().stroke(Color.filmBorder, lineWidth: 0.5))
            )
            .padding(.bottom, 24)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func applyFilter() {
        guard let cgImage = image.cgImage else { return }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        var filtered = ciImage

        switch selectedFilter {
        case .none: filtered = ciImage
        case .blackAndWhite:
            if let filter = CIFilter(name: "CIPhotoEffectNoir") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filtered = filter.outputImage ?? ciImage
            }
        case .sepia:
            if let filter = CIFilter(name: "CISepiaTone") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(intensity, forKey: kCIInputIntensityKey)
                filtered = filter.outputImage ?? ciImage
            }
        case .vintage:
            if let filter = CIFilter(name: "CIPhotoEffectInstant") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filtered = filter.outputImage ?? ciImage
            }
        case .highContrast:
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(contrast * 1.5, forKey: kCIInputContrastKey)
                filtered = filter.outputImage ?? ciImage
            }
        case .fade:
            if let filter = CIFilter(name: "CIPhotoEffectFade") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filtered = filter.outputImage ?? ciImage
            }
        }

        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(filtered, forKey: kCIInputImageKey)
            colorControls.setValue(contrast, forKey: kCIInputContrastKey)
            colorControls.setValue(brightness, forKey: kCIInputBrightnessKey)
            filtered = colorControls.outputImage ?? filtered
        }

        if let output = context.createCGImage(filtered, from: filtered.extent) {
            processedImage = UIImage(cgImage: output)
        }
    }

    private func saveImage() {
        guard let final = processedImage else { return }
        UIImageWriteToSavedPhotosAlbum(final, nil, nil, nil)
        withAnimation(.spring(response: 0.3)) {
            showSaveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                showSaveSuccess = false
            }
        }
        onSave(final)
        dismiss()
    }
}

enum FilmFilter: CaseIterable {
    case none, blackAndWhite, sepia, vintage, highContrast, fade
    var displayName: String {
        switch self {
        case .none: return "Original"
        case .blackAndWhite: return "B&W"
        case .sepia: return "Sepia"
        case .vintage: return "Vintage"
        case .highContrast: return "Contrast"
        case .fade: return "Fade"
        }
    }
    var icon: String {
        switch self {
        case .none: return "🎞️"
        case .blackAndWhite: return "◐"
        case .sepia: return "☕"
        case .vintage: return "📷"
        case .highContrast: return "◑"
        case .fade: return "🌫️"
        }
    }
}
