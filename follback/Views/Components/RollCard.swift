import SwiftUI
import SwiftData
import Kingfisher

struct RollCard: View {
    let roll: Roll
    let onDelete: () -> Void
    let onArchive: () -> Void
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 14) {
            filmCoverThumbnail

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(roll.filmName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmText)
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }

                HStack(spacing: 4) {
                    Image(systemName: "camera")
                        .font(.system(size: 10))
                    Text(roll.camera?.name ?? "No camera")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.filmTertiary)

                HStack(spacing: 12) {
                    specLabel("ISO \(roll.iso)")
                    specLabel(roll.filmFormat.displayName)
                    specLabel("\(roll.filledFrames)/\(roll.capacity)")
                }

                progressBar
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                )
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    // MARK: - Components

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private var filmCoverThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.filmSurfaceSecondary)
                .frame(width: 48, height: 48)

            if let stock = matchingFilmStock,
               let coverUrlString = stock.fullCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .requestModifier(FilmerImageAuth.shared.modifier)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }
        }
    }

    private var statusBadge: some View {
        Text(roll.rollStatus.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(statusColor.opacity(0.1))
            )
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.filmSprocket)
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.filmAccent)
                    .frame(
                        width: geo.size.width * CGFloat(roll.filledFrames) / CGFloat(max(roll.capacity, 1)),
                        height: 3
                    )
                    .animation(.easeOut(duration: 0.5), value: roll.filledFrames)
            }
        }
        .frame(height: 3)
    }

    private func specLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(Color.filmSecondary)
    }

    private var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .developed: return Color.filmSuccess
        case .archived: return Color.filmTertiary
        }
    }
}
