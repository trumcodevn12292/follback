import SwiftUI

struct ShareTemplateView: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ShareTemplate = .polaroid
    @State private var showActivitySheet = false
    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    templatePreview
                        .frame(height: 420)
                        .padding(.horizontal, 16)

                    templateSelector

                    Button {
                        renderAndShare()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.filmAccent)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.filmText)
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .sheet(isPresented: $showActivitySheet) {
            if let rendered = renderedImage {
                ShareSheet(activityItems: [rendered])
            }
        }
    }

    private var templatePreview: some View {
        Group {
            switch selectedTemplate {
            case .polaroid:
                PolaroidTemplate(image: image, frame: frame, roll: roll)
            case .filmStrip:
                FilmStripTemplate(image: image, frame: frame, roll: roll)
            case .darkroom:
                DarkroomTemplate(image: image, frame: frame, roll: roll)
            }
        }
    }

    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ShareTemplate.allCases, id: \.self) { template in
                        templateButton(template)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func templateButton(_ template: ShareTemplate) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTemplate = template
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.filmSurface)
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedTemplate == template ? Color.filmAccent : Color.filmBorder, lineWidth: selectedTemplate == template ? 2 : 1)
                        )
                    Image(systemName: template.icon)
                        .font(.system(size: 24))
                        .foregroundColor(selectedTemplate == template ? Color.filmAccent : Color.filmTertiary)
                }
                Text(template.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(selectedTemplate == template ? Color.filmAccent : Color.filmSecondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(selectedTemplate == template ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedTemplate)
    }

    private func renderAndShare() {
        let renderer = ImageRenderer(content: templatePreview)
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            showActivitySheet = true
        }
    }
}

enum ShareTemplate: CaseIterable {
    case polaroid, filmStrip, darkroom

    var displayName: String {
        switch self {
        case .polaroid: return "Polaroid"
        case .filmStrip: return "Film Strip"
        case .darkroom: return "Darkroom"
        }
    }

    var icon: String {
        switch self {
        case .polaroid: return "rectangle.fill"
        case .filmStrip: return "film.fill"
        case .darkroom: return "photo.fill"
        }
    }
}

struct PolaroidTemplate: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text(roll.filmName)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(Color.filmText)
                if let ap = frame.apertureDisplay, let sh = frame.shutterDisplay {
                    Text("\(ap)  ·  \(sh)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.filmSecondary)
                }
                Text("Frame #\(frame.number)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.filmTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 6)
        )
    }
}

struct FilmStripTemplate: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(0..<6) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.filmSprocket)
                            .frame(width: 8, height: 20)
                    }
                }
                .padding(.vertical, 8)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 12)

                HStack(spacing: 4) {
                    ForEach(0..<6) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.filmSprocket)
                            .frame(width: 8, height: 20)
                    }
                }
                .padding(.vertical, 8)

                HStack {
                    Text("\(roll.filmName) · #\(frame.number)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.filmSecondary)
                    Spacer()
                    if let ap = frame.apertureDisplay {
                        Text(ap)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color.filmSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DarkroomTemplate: View {
    let image: UIImage
    let frame: Frame
    let roll: Roll

    var body: some View {
        ZStack {
            Color.filmBackground

            VStack(spacing: 12) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.filmBorder, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(roll.filmName)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(Color.filmText)

                    HStack(spacing: 8) {
                        if let ap = frame.apertureDisplay {
                            Text(ap)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
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
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.filmAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.filmAccent.opacity(0.12))
                                )
                        }
                    }

                    Text("Frame #\(frame.number) · \(roll.camera?.name ?? "")")
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.filmBorder, lineWidth: 1)
        )
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
