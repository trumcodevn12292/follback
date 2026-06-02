import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct DarkroomView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: FilmPreset = .original
    @State private var intensity: Double = 1.0
    @State private var contrast: Double = 1.0
    @State private var brightness: Double = 0.0
    @State private var processedImage: UIImage?
    @State private var showSaveSuccess = false

    private let context = CIContext()

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                imagePreview
                controlsPanel
            }

            if showSaveSuccess {
                successToast
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.filmSurface)
                            .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                    )
            }
            Spacer()
            Text("Darkroom")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
            Spacer()
            Button {
                saveToPhotos()
            } label: {
                Text("Save")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.filmBackground)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.filmAccent, Color.filmGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var imagePreview: some View {
        Image(uiImage: processedImage ?? image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
    }

    private var controlsPanel: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FilmPreset.allCases, id: \.self) { preset in
                        presetButton(preset)
                    }
                }
                .padding(.horizontal, 16)
            }

            VStack(spacing: 14) {
                sliderRow(label: "Intensity", value: $intensity, range: 0...2, color: Color.filmAccent)
                sliderRow(label: "Contrast", value: $contrast, range: 0.5...2, color: Color.filmGold)
                sliderRow(label: "Brightness", value: $brightness, range: -0.5...0.5, color: Color.filmCopper)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: -5)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func presetButton(_ preset: FilmPreset) -> some View {
        let isSelected = selectedPreset == preset
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedPreset = preset
                applyFilter()
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.filmSprocket)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(preset.emoji)
                            .font(.system(size: 24))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                ? LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.filmBorder, Color.filmBorder], startPoint: .leading, endPoint: .trailing),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )
                    .shadow(color: isSelected ? Color.filmAccent.opacity(0.3) : .clear, radius: 6, x: 0, y: 3)

                Text(preset.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
                .frame(width: 70, alignment: .leading)

            Slider(value: value, in: range)
                .tint(color)
                .onChange(of: value.wrappedValue) { _, _ in
                    applyFilter()
                }

            Text(String(format: "%.1f", value.wrappedValue))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 30)
        }
    }

    private var successToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.filmSuccess)
                Text("Saved to Photos")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color.filmSurface.opacity(0.8)))
                    .overlay(Capsule().stroke(Color.filmBorder, lineWidth: 0.5))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
            .padding(.bottom, 120)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func applyFilter() {
        guard let ciImage = CIImage(image: image) else { return }
        var output = ciImage

        switch selectedPreset {
        case .original:
            break
        case .bw:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = output
            if let result = filter.outputImage { output = result }
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = output
            filter.intensity = Float(intensity)
            if let result = filter.outputImage { output = result }
        case .vintage:
            let filter = CIFilter.photoEffectTransfer()
            filter.inputImage = output
            if let result = filter.outputImage { output = result }
        case .highContrast:
            break
        case .fade:
            let filter = CIFilter.photoEffectFade()
            filter.inputImage = output
            if let result = filter.outputImage { output = result }
        }

        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = output
        colorFilter.contrast = Float(contrast)
        colorFilter.brightness = Float(brightness)
        if let result = colorFilter.outputImage { output = result }

        if let cgImg = context.createCGImage(output, from: output.extent) {
            processedImage = UIImage(cgImage: cgImg)
        }
    }

    private func saveToPhotos() {
        guard let img = processedImage ?? Optional(image) else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        withAnimation(.spring(response: 0.3)) {
            showSaveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                showSaveSuccess = false
            }
        }
        onSave(img)
    }
}

enum FilmPreset: String, CaseIterable {
    case original, bw, sepia, vintage, highContrast, fade

    var name: String {
        switch self {
        case .original: return "Original"
        case .bw: return "B&W"
        case .sepia: return "Sepia"
        case .vintage: return "Vintage"
        case .highContrast: return "Contrast"
        case .fade: return "Fade"
        }
    }

    var emoji: String {
        switch self {
        case .original: return "🎞️"
        case .bw: return "⬛"
        case .sepia: return "🟤"
        case .vintage: return "📷"
        case .highContrast: return "◑"
        case .fade: return "🌫️"
        }
    }
}
