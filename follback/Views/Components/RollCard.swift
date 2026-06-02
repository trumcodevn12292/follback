import SwiftUI
import SwiftData
import Kingfisher

struct RollCard: View {
    let roll: Roll
    let onDelete: () -> Void
    let onArchive: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                statusBar
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        filmCoverThumbnail

                        VStack(alignment: .leading, spacing: 5) {
                            Text(roll.filmName)
                                .font(.system(size: 19, weight: .bold, design: .serif))
                                .foregroundColor(Color.filmText)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.filmTertiary)
                                Text(roll.camera?.name ?? "No camera")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.filmSecondary)
                            }
                        }

                        Spacer()

                        statusBadge
                    }

                    HStack(spacing: 8) {
                        specBadge(icon: "film", text: "ISO \(roll.iso)")
                        specBadge(icon: "square.grid.2x2", text: "\(roll.capacity)")
                        specBadge(icon: "viewfinder", text: roll.filmFormat.displayName)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.filmSprocket)
                                    .frame(height: 7)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(gradientFill)
                                    .frame(
                                        width: geo.size.width * CGFloat(roll.filledFrames) / CGFloat(max(roll.capacity, 1)),
                                        height: 7
                                    )
                                    .shadow(color: Color.filmAccent.opacity(0.35), radius: 6, x: 0, y: 2)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: roll.filledFrames)
                            }
                        }
                        .frame(height: 7)

                        HStack {
                            Text("\(roll.filledFrames)/\(roll.capacity) frames")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.filmTertiary)
                            Spacer()
                            if roll.pushPull != 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 9))
                                    Text(String(format: "%+.1f", roll.pushPull))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                }
                                .foregroundColor(Color.filmGold)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 14)
            }
        }
        .filmCard(cornerRadius: 22)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private var filmCoverThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.filmSurface)
                .frame(width: 42, height: 42)

            if let stock = matchingFilmStock,
               let coverUrlString = stock.fullCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmAccent.opacity(0.5))
            }
        }
    }

    private var statusBar: some View {
        LinearGradient(
            colors: [statusColor, statusColor.opacity(0.5)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(roll.rollStatus.displayName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(statusColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .developed: return Color.filmSuccess
        case .archived: return Color.filmTertiary
        }
    }

    private var gradientFill: LinearGradient {
        LinearGradient(
            colors: [Color.filmAccent, Color.filmGold],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func specBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color.filmAccent.opacity(0.7))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.filmSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.filmSurfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.filmBorder.opacity(0.5), lineWidth: 0.5)
                )
        )
    }
}
