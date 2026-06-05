import SwiftUI
import Photos

struct ARGalleryView: View {
    let roll: Roll
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFrames: Set<Int> = []
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var isLoading = true
    @State private var showARView = false

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0908").ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Color(hex: "#C8BAA8"))
                } else {
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 100), spacing: 8)
                            ], spacing: 8) {
                                ForEach(photoFrames) { frame in
                                    photoThumb(frame)
                                }
                            }
                            .padding(16)
                        }

                        Divider()
                            .background(Color(hex: "#C8BAA8").opacity(0.2))

                        HStack(spacing: 12) {
                            Text("\(selectedFrames.count) selected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#9A8E7E"))

                            Spacer()

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showARView = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arkit")
                                        .font(.system(size: 16))
                                    Text("View in AR")
                                        .font(.system(size: 14, weight: .semibold))
                                    if !selectedFrames.isEmpty {
                                        Text("(\(selectedFrames.count))")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(selectedFrames.isEmpty
                                            ? Color(hex: "#C8BAA8").opacity(0.2)
                                            : Color(hex: "#C8BAA8"))
                                )
                            }
                            .disabled(selectedFrames.isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("AR Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#9A8E7E"))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                }
                if !selectedFrames.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Select All") {
                            if selectedFrames.count == photoFrames.count {
                                selectedFrames.removeAll()
                            } else {
                                selectedFrames = Set(photoFrames.map(\.number))
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#C8BAA8"))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showARView) {
            ARPhotoGalleryView(images: selectedImages)
        }
        .task {
            await loadImages()
        }
    }

    private var selectedImages: [UIImage] {
        photoFrames
            .filter { selectedFrames.contains($0.number) }
            .compactMap { loadedImages[$0.number] }
    }

    private func photoThumb(_ frame: Frame) -> some View {
        let isSelected = selectedFrames.contains(frame.number)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                if isSelected {
                    selectedFrames.remove(frame.number)
                } else {
                    selectedFrames.insert(frame.number)
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                if let image = loadedImages[frame.number] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                } else {
                    Color(hex: "#1C1408")
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(Color(hex: "#9A8E7E").opacity(0.4))
                        }
                }

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#C8BAA8"))
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#0A0908"))
                    }
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color(hex: "#C8BAA8") : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .bottomLeading) {
                Text("#\(frame.number)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
            }
            .contentShape(.interaction, RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func loadImages() async {
        let frames = photoFrames

        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for frame in frames {
                group.addTask {
                    guard let assetID = frame.photoAssetID else { return (frame.number, nil) }
                    let img = await loadSingleImage(assetID: assetID)
                    return (frame.number, img)
                }
            }

            for await (number, image) in group {
                if let image {
                    await MainActor.run { loadedImages[number] = image }
                }
            }
        }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.5)) { isLoading = false }
        }
    }

    private func loadSingleImage(assetID: String) async -> UIImage? {
        if !assetID.contains("/") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            return await Task.detached(priority: .userInitiated) {
                downsampledImage(at: url, maxPixel: 400)
            }.value
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            let targetSize = CGSize(width: 400, height: 400)
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
