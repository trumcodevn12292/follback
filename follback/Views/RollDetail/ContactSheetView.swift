import SwiftUI
import Photos
import Kingfisher

// MARK: - Contact Sheet View

struct ContactSheetView: View {
    let roll: Roll
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var isLoading = true
    @State private var savedToPhotos = false
    @State private var isSaving = false
    @State private var coverImage: UIImage?
    @State private var preloadedLabLogo: UIImage?

    private let columns = 4
    private let filmBase = Color(hex: "#1C1408")
    private let rebateText = Color(hex: "#C86B28")
    private let paperBg = Color(hex: "#F5F0E8")
    private let inkColor = Color(hex: "#2A2218")

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private var matchingLab: FilmLab? {
        guard let labName = roll.labName else { return nil }
        return FilmLab.allLabs.first { $0.name == labName }
    }

    private var matchingCustomLab: CustomLab? {
        guard let labName = roll.labName else { return nil }
        return CustomLabStore.shared.lab(named: labName)
    }

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.filmSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.filmSurface.opacity(0.5)))
                    }
                    Spacer()
                    Text("CONTACT SHEET")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color.filmText)
                        .kerning(2)
                    Spacer()
                    Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); saveContactSheet() } label: {
                        if isSaving {
                            ProgressView()
                                .tint(Color.filmSecondary)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(savedToPhotos ? .green : Color.filmText)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.filmSurface.opacity(0.5)))
                        }
                    }
                    .disabled(isSaving || isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    contactSheetContent(fontSize: 1.0)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }

            if savedToPhotos {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        Text("Saved to Photos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.filmText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.filmSurface))
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await loadAllImages()
            await loadCoverImage()
            await preloadLabLogoImage()
            withAnimation(.easeOut(duration: 0.5)) { isLoading = false }
        }
    }

    // MARK: - Shared Content
    private func contactSheetContent(fontSize: CGFloat) -> some View {
        let rows = stride(from: 0, to: photoFrames.count, by: columns).map {
            Array(photoFrames[$0..<min($0 + columns, photoFrames.count)])
        }

        return VStack(spacing: 0) {
            // Header with film cover + info
            HStack(spacing: 10 * fontSize) {
                // Film cover
                if let cover = coverImage {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44 * fontSize, height: 44 * fontSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6 * fontSize, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 6 * fontSize, style: .continuous)
                        .fill(Color(hex: "#DDD5C8"))
                        .frame(width: 44 * fontSize, height: 44 * fontSize)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 16 * fontSize, weight: .light))
                                .foregroundColor(Color(hex: "#9A8E7E"))
                        )
                }

                VStack(alignment: .leading, spacing: 3 * fontSize) {
                    Text(roll.filmName.uppercased())
                        .font(.system(size: 12 * fontSize, weight: .black, design: .monospaced))
                        .foregroundColor(inkColor)
                        .kerning(1 * fontSize)
                        .lineLimit(1)

                    HStack(spacing: 6 * fontSize) {
                        if let camera = roll.camera {
                            Text(camera.name.uppercased())
                                .font(.system(size: 6 * fontSize, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "#6A5E4E"))
                                .lineLimit(1)
                        }
                        Text("ISO \(roll.iso)")
                            .font(.system(size: 6 * fontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#6A5E4E"))
                        Text(roll.format.uppercased())
                            .font(.system(size: 6 * fontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#6A5E4E"))
                    }

                    Text(roll.startDate.formatted(.dateTime.month(.wide).day().year().locale(appLocale())).uppercased())
                        .font(.system(size: 6 * fontSize, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#9A8E7E"))

                    if let loc = roll.locationName, !loc.isEmpty {
                        HStack(spacing: 2 * fontSize) {
                            Image(systemName: "mappin")
                                .font(.system(size: 5 * fontSize))
                            Text(loc.uppercased())
                                .font(.system(size: 6 * fontSize, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(hex: "#9A8E7E"))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12 * fontSize)
            .padding(.top, 14 * fontSize)
            .padding(.bottom, 10 * fontSize)

            // Divider
            Rectangle()
                .fill(Color(hex: "#D5CCBE"))
                .frame(height: 0.5 * fontSize)
                .padding(.horizontal, 12 * fontSize)

            // Film strips
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                filmStripRow(row: row, scale: fontSize)
                    .padding(.vertical, 2 * fontSize)
            }

            // Footer with lab info
            HStack(spacing: 0) {
                // Lab info (left)
                if let lab = matchingLab {
                    HStack(spacing: 4 * fontSize) {
                        if let preloaded = preloadedLabLogo {
                            Image(uiImage: preloaded)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 14 * fontSize, height: 14 * fontSize)
                                .clipShape(Circle())
                        } else if let logoUrl = lab.logoUrl, let url = URL(string: logoUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                labInitialCircle(lab: lab, fontSize: fontSize)
                            }
                            .frame(width: 14 * fontSize, height: 14 * fontSize)
                            .clipShape(Circle())
                        } else {
                            labInitialCircle(lab: lab, fontSize: fontSize)
                        }
                        Text(lab.name.uppercased())
                            .font(.system(size: 5 * fontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#9A8E7E"))
                            .lineLimit(1)
                    }
                } else if let custom = matchingCustomLab {
                    HStack(spacing: 4 * fontSize) {
                        CustomLabAvatar(lab: custom, size: 14 * fontSize)
                        Text(custom.name.uppercased())
                            .font(.system(size: 5 * fontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#9A8E7E"))
                            .lineLimit(1)
                    }
                } else {
                    Text("FILMVAULT")
                        .font(.system(size: 6 * fontSize, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#C8BAA8"))
                        .kerning(3 * fontSize)
                }

                Spacer()

                Text(L("%d EXPOSURES", photoFrames.count))
                    .font(.system(size: 6 * fontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#C8BAA8"))
            }
            .padding(.horizontal, 12 * fontSize)
            .padding(.vertical, 10 * fontSize)
        }
        .padding(.horizontal, 6 * fontSize)
        .background(paperBg)
    }

    private func labInitialCircle(lab: FilmLab, fontSize: CGFloat) -> some View {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        let hash = abs(lab.name.hashValue) % colors.count
        return Text(String(lab.name.prefix(1)))
            .font(.system(size: 7 * fontSize, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 14 * fontSize, height: 14 * fontSize)
            .background(Circle().fill(colors[hash]))
    }

    private func loadCoverImage() {
        guard let stock = matchingFilmStock,
              let coverUrlString = stock.githubCoverUrl,
              let url = URL(string: coverUrlString) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data) else { return }
            await MainActor.run { coverImage = img }
        }
    }

    private func preloadLabLogoImage() async {
        guard let lab = matchingLab, let logoUrl = lab.logoUrl, let url = URL(string: logoUrl) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return }
        await MainActor.run { preloadedLabLogo = img }
    }

    // MARK: - Film Strip Row
    private func filmStripRow(row: [Frame], scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            sprocketRail(count: columns * 2, scale: scale)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    HStack(spacing: 0) {
                        Text("\(frame.number)")
                            .font(.system(size: 5 * scale, weight: .bold, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.7))
                        Spacer()
                        Text("\(frame.number)A")
                            .font(.system(size: 4 * scale, weight: .medium, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.35))
                    }
                    .padding(.horizontal, 3 * scale)
                    .frame(maxWidth: .infinity)
                }
                if row.count < columns {
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 10 * scale)
                    }
                }
            }
            .frame(height: 12 * scale)
            .background(filmBase)

            HStack(spacing: 1 * scale) {
                ForEach(row, id: \.id) { frame in
                    ZStack {
                        Color(hex: "#0D0A06")
                        if let img = loadedImages[frame.number] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .aspectRatio(3.0/2.0, contentMode: .fit)
                    .clipped()
                }
                if row.count < columns {
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color(hex: "#0D0A06")
                            .aspectRatio(3.0/2.0, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 3 * scale)
            .background(filmBase)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    HStack(spacing: 0) {
                        Text("◀ \(frame.number)")
                            .font(.system(size: 4 * scale, weight: .medium, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 3 * scale)
                    .frame(maxWidth: .infinity)
                }
                if row.count < columns {
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 10 * scale)
                    }
                }
            }
            .frame(height: 12 * scale)
            .background(filmBase)

            sprocketRail(count: columns * 2, scale: scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5 * scale))
    }

    private func sprocketRail(count: Int, scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                Spacer()
                RoundedRectangle(cornerRadius: 0.4 * scale)
                    .fill(paperBg)
                    .frame(width: 3.5 * scale, height: 2 * scale)
                Spacer()
            }
        }
        .frame(height: 5 * scale)
        .background(filmBase)
    }

    // MARK: - Load Images
    private func loadAllImages() {
        let frames = photoFrames

        Task.detached(priority: .userInitiated) {
            for frame in frames {
                guard let assetID = frame.photoAssetID else { continue }

                if !assetID.contains("/") {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent(assetID)
                    let img = autoreleasepool {
                        downsampledImage(at: url, maxPixel: 600)
                    }
                    if let img {
                        await MainActor.run { loadedImages[frame.number] = img }
                    }
                    continue
                }

                let results = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
                guard let asset = results.firstObject else { continue }

                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = false
                options.resizeMode = .fast

                let targetSize = CGSize(width: 600, height: 600)
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                    if let image = image {
                        DispatchQueue.main.async {
                            loadedImages[frame.number] = image
                        }
                    }
                }
            }
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Save
    @MainActor
    private func saveContactSheet() {
        isSaving = true

        let exportView = contactSheetContent(fontSize: 2.0)
            .frame(width: 540)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0

        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4)) {
                savedToPhotos = true
                isSaving = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { savedToPhotos = false }
            }
        } else {
            isSaving = false
        }
    }
}
