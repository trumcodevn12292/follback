import SwiftUI
import MapKit
import SwiftData
import Photos

struct RollsMapView: View {
    let rolls: [Roll]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedRoll: Roll?
    @State private var selectedFrame: Frame?
    @State private var showFrames = false
    @State private var showRollDetail = false
    @State private var showFrameEditor = false
    @State private var coverImages: [UUID: UIImage] = [:]

    private var rollsWithLocation: [Roll] {
        rolls.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var framesWithLocation: [(Frame, Roll)] {
        rolls.flatMap { roll in
            (roll.frames ?? [])
                .filter { $0.latitude != nil && $0.longitude != nil }
                .map { ($0, roll) }
        }
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, selection: selectedItem) {
                if showFrames {
                    ForEach(framesWithLocation, id: \.0.id) { frame, roll in
                        Annotation(
                            frame.locationName ?? "#\(frame.number)",
                            coordinate: CLLocationCoordinate2D(
                                latitude: frame.latitude!,
                                longitude: frame.longitude!
                            )
                        ) {
                            annotationBadge(
                                coverImage: coverImages[roll.id],
                                label: "#\(frame.number)",
                                isFrame: true
                            )
                        }
                        .tag(MapItem.frame(frame, roll))
                    }
                } else {
                    ForEach(rollsWithLocation) { roll in
                        Annotation(
                            roll.locationName ?? roll.filmName,
                            coordinate: CLLocationCoordinate2D(
                                latitude: roll.latitude!,
                                longitude: roll.longitude!
                            )
                        ) {
                            annotationBadge(
                                coverImage: coverImages[roll.id],
                                label: roll.filmName,
                                isFrame: false
                            )
                        }
                        .tag(MapItem.roll(roll))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }
        }
        .sheet(item: $selectedRoll) { roll in
            rollDetailSheet(roll)
        }
        .sheet(item: $selectedFrame) { frame in
            frameEditorSheet(frame)
        }
        .task { await loadCovers() }
    }

    private var selectedItem: Binding<MapItem?> {
        Binding(
            get: {
                if let roll = selectedRoll { return .roll(roll) }
                if let frame = selectedFrame, let roll = frame.roll { return .frame(frame, roll) }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .roll(let roll): selectedRoll = roll
                case .frame(let frame, _): selectedFrame = frame
                case nil:
                    selectedRoll = nil
                    selectedFrame = nil
                }
            }
        )
    }

    enum MapItem: Equatable {
        case roll(Roll)
        case frame(Frame, Roll)

        static func == (lhs: MapItem, rhs: MapItem) -> Bool {
            switch (lhs, rhs) {
            case (.roll(let a), .roll(let b)): a.id == b.id
            case (.frame(let a, _), .frame(let b, _)): a.id == b.id
            default: false
            }
        }
    }

    // MARK: - Annotation Badge

    private func annotationBadge(coverImage: UIImage?, label: String, isFrame: Bool) -> some View {
        VStack(spacing: 2) {
            if let cover = coverImage {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3)
            } else {
                Image(systemName: isFrame ? "circle.fill" : "square.fill")
                    .font(.system(size: isFrame ? 10 : 14))
                    .foregroundColor(isFrame ? Color.filmTertiary : Color.filmCopper)
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: isFrame ? 18 : 24, height: isFrame ? 18 : 24)
                    )
            }
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) { showFrames.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showFrames ? "photo.on.rectangle" : "film.stack")
                        .font(.system(size: 12, weight: .bold))
                    Text(showFrames ? L("Frames") : L("Rolls"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
            }

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            if showFrames {
                Text(L("%d frames with location", framesWithLocation.count))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text(L("%d rolls with location", rollsWithLocation.count))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Cover Loading

    private func matchingFilmStock(for roll: Roll) -> FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private func loadCovers() async {
        for roll in rollsWithLocation {
            guard let stock = matchingFilmStock(for: roll),
                  let urlString = stock.githubCoverUrl,
                  let url = URL(string: urlString) else { continue }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data) else { continue }
            await MainActor.run { coverImages[roll.id] = img }
        }
    }

    // MARK: - Roll Detail Sheet

    private func rollDetailSheet(_ roll: Roll) -> some View {
        NavigationStack {
            VStack(spacing: 12) {
                let frames = (roll.frames ?? []).filter { $0.photoAssetID != nil }.sorted { $0.number < $1.number }

                if let firstFrame = frames.first, let assetID = firstFrame.photoAssetID {
                    FrameThumbnail(assetID: assetID)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(roll.filmName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.filmText)

                    if let loc = roll.locationName {
                        Label(loc, systemImage: "mappin")
                            .font(.system(size: 14))
                            .foregroundColor(Color.filmSecondary)
                    }

                    HStack(spacing: 12) {
                        if let camera = roll.camera {
                            Label(camera.name, systemImage: "camera")
                                .font(.system(size: 13))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Text(L("%d photos", frames.count))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.filmTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.filmBackground)
            .navigationTitle(roll.filmName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Close")) { selectedRoll = nil }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(L("View Roll")) {
                        RollDetailView(roll: roll)
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Frame Editor Sheet

    private func frameEditorSheet(_ frame: Frame) -> some View {
        guard let roll = frame.roll else {
            return NavigationStack {
                Text("Error loading frame")
            }
        }
        return NavigationStack {
            FrameEditorView(roll: roll, frame: frame, currentNumber: frame.number)
        }
    }
}

// MARK: - Frame Thumbnail Helper

private struct FrameThumbnail: View {
    let assetID: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.filmSurfaceSecondary
                    .overlay {
                        ProgressView().tint(Color.filmTertiary)
                    }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        if !assetID.contains("/") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            DispatchQueue.global(qos: .userInitiated).async {
                let img = downsampledImage(at: url, maxPixel: 400)
                DispatchQueue.main.async { image = img }
            }
        } else {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = result.firstObject else { return }
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: nil
            ) { img, _ in
                if let img { image = img }
            }
        }
    }
}

// MARK: - MapItem Hashable conformance

extension RollsMapView.MapItem: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .roll(let roll): hasher.combine(roll.id)
        case .frame(let frame, _): hasher.combine(frame.id)
        }
    }
}
