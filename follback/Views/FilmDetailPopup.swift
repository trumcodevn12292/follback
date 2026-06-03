import SwiftUI
import Kingfisher

struct FilmDetailPopup: View {
    let stock: FilmStock
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dimmed background — tap to dismiss
            Color.black.opacity(appeared ? 0.7 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card
            VStack(spacing: 0) {
                // Cover image
                ZStack(alignment: .topTrailing) {
                    if let coverUrlString = stock.fullCoverUrl,
                       let coverURL = URL(string: coverUrlString) {
                        KFImage(coverURL)
                            .requestModifier(FilmerImageAuth.shared.modifier)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [stock.color.opacity(0.3), stock.accentColor.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 280)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 48, weight: .thin))
                                    .foregroundColor(stock.color.opacity(0.5))
                            )
                    }

                    // Close button
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(12)
                }

                // Info section
                VStack(alignment: .leading, spacing: 16) {
                    // Title + brand
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stock.brand)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.filmTertiary)
                            .textCase(.uppercase)
                            .kerning(0.5)

                        Text(stock.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.filmText)
                    }

                    // Specs row
                    HStack(spacing: 16) {
                        specChip(label: "ISO", value: "\(stock.isoValue)")
                        specChip(label: "Type", value: stock.type.rawValue)
                        if let process = stock.process {
                            specChip(label: "Process", value: process)
                        }
                        specChip(label: "Frames", value: "\(stock.frameCount)")
                    }

                    // Description
                    if let description = stock.filmDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(Color.filmSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Format tags
                    if !stock.frameFormats.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(stock.frameFormats, id: \.self) { format in
                                Text(format)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.filmTertiary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.filmBorder.opacity(0.2))
                                    )
                            }

                            if stock.inProduction {
                                Text("In Production")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.green.opacity(0.8))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.green.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.filmSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func specChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.filmTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.filmText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
