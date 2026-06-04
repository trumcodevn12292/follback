import SwiftUI
import SwiftData
import Kingfisher
import UIKit

struct RollCard: View {
    let roll: Roll
    let onDelete: () -> Void
    let onArchive: () -> Void
    let onEditDetails: () -> Void
    var onCoverTap: ((FilmStock) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section: cover + info
            HStack(alignment: .top, spacing: 14) {
                filmCoverThumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(roll.filmName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.filmText)
                        .lineLimit(1)

                    Text(rollDateText)
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                        .lineLimit(2)

                    if let location = roll.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(location)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color.filmTertiary)
                    }
                }

                Spacer()

                if roll.filledFrames > 0 {
                    Text(L("%d photos", roll.filledFrames))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Photo preview row
            if !photoFrames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(photoFrames.prefix(4), id: \.id) { frame in
                            if let assetID = frame.photoAssetID {
                                PhotoThumbnail(assetID: assetID)
                                    .frame(width: photoPreviewSize, height: photoPreviewSize)
                                    .clipped()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            } else {
                // Empty state inside card
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("No rolls yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.filmTertiary)
                        Text("Start documenting your analog\nphotography journey")
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmTertiary.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
        )
        .contextMenu {
            Button(action: onEditDetails) {
                Label("Edit Details", systemImage: "pencil")
            }
            Button(action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Components

    private var photoPreviewSize: CGFloat {
        80
    }

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private var matchingCustomFilm: CustomFilm? {
        CustomFilmStore.shared.films.first {
            $0.name.lowercased() == roll.filmName.lowercased()
        }
    }

    private var filmCoverThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.filmSurfaceSecondary)
                .frame(width: 80, height: 80)

            if let custom = matchingCustomFilm,
               let data = custom.coverImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let stock = matchingFilmStock,
               let coverUrlString = stock.githubCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .downsampling(size: CGSize(width: 160, height: 160))
                    .cacheOriginalImage()
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }
        }
        .onTapGesture {
            if let stock = matchingFilmStock {
                onCoverTap?(stock)
            }
        }
    }

    private var rollDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: roll.startDate)
    }
}
