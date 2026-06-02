import SwiftUI

struct ShareTemplateView: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate = 0
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        templatePreview
                        templatePicker
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                shareButton
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let rendered = renderedImage {
                ShareSheet(activityItems: [rendered])
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
            Text("Share")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var templatePreview: some View {
        switch selectedTemplate {
        case 0:
            polaroidTemplate
        case 1:
            filmStripTemplate
        default:
            darkroomTemplate
        }
    }

    private var templatePicker: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let labels = ["Polaroid", "Film Strip", "Darkroom"]
                let icons = ["rectangle.portrait", "film", "circle.dotted"]
                let isSelected = selectedTemplate == index
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTemplate = index
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: icons[index])
                            .font(.system(size: 18))
                        Text(labels[index])
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(isSelected ? Color.filmBackground : Color.filmSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                isSelected
                                ? AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.filmSurface)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : Color.filmBorder, lineWidth: 0.5)
                    )
                    .shadow(color: isSelected ? Color.filmAccent.opacity(0.25) : .clear, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shareButton: some View {
        Button {
            renderAndShare()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                Text("Share")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.filmAccent.opacity(0.35), radius: 12, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var polaroidTemplate: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(16)

            VStack(alignment: .leading, spacing: 4) {
                Text(roll.filmName)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.black)
                HStack(spacing: 6) {
                    if let ap = frame.apertureDisplay {
                        Text(ap)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    if let sh = frame.shutterDisplay {
                        Text(sh)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    Text("Frame #\(frame.number)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    private var filmStripTemplate: some View {
        VStack(spacing: 0) {
            sprocketRow
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            sprocketRow

            HStack {
                Text(roll.filmName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                Text("Frame #\(frame.number)")
                    .font(.system(size: 12, design: .monospaced))
            }
            .foregroundColor(Color.filmAccent)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var sprocketRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<16, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.filmTertiary.opacity(0.4))
                    .frame(width: 12, height: 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var darkroomTemplate: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(16)

            VStack(alignment: .leading, spacing: 8) {
                Text(roll.filmName)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)

                HStack(spacing: 8) {
                    if let ap = frame.apertureDisplay {
                        Text(ap)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.filmAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.filmAccent.opacity(0.12))
                            )
                    }
                    if let sh = frame.shutterDisplay {
                        Text(sh)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.filmGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.filmGold.opacity(0.12))
                            )
                    }
                }

                Text("Frame #\(frame.number) · \(roll.camera?.name ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.filmBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.filmBorder, lineWidth: 1)
        )
    }

    @MainActor
    private func renderAndShare() {
        let renderer = ImageRenderer(content: templatePreview.frame(width: 390))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
