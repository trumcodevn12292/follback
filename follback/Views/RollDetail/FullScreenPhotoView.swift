import SwiftUI
import PhotosUI
import Photos
import Kingfisher

// MARK: - Full Screen Photo View (iOS Photos style)
struct FullScreenPhotoView: View {
    let frame: Frame
    let roll: Roll
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showInfo = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var currentIndex: Int = 0

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    @State private var currentImage: UIImage?
    @State private var shareImage: UIImage?
    @State private var showShareMenu = false
    @State private var showSaveToast = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photoFrames.enumerated()), id: \.element.id) { index, photoFrame in
                    PhotoPageView(frame: photoFrame, onDismiss: { dismiss() }, loadedImage: $currentImage)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Top bar
            VStack {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    if currentIndex < photoFrames.count {
                        Text("\(currentIndex + 1) / \(photoFrames.count)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation { showInfo.toggle() }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showShareMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if showInfo, currentIndex < photoFrames.count {
                    infoBarFor(photoFrames[currentIndex])
                }
            }
        }
        .background(ShareController(image: shareImage, onComplete: { shareImage = nil }))
        .overlay {
            if showShareMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showShareMenu = false
                        }
                    }
                shareMenu
            }
        }
        .overlay(alignment: .top) {
            if showSaveToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L("Saved to Photos"))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSaveToast = false }
                    }
                }
            }
        }
        .onDisappear { showShareMenu = false }
        .onAppear {
            if let idx = photoFrames.firstIndex(where: { $0.id == frame.id }) {
                currentIndex = idx
            }
        }
    }

    private func infoBarFor(_ f: Frame) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let ap = f.apertureDisplay {
                    infoChip(icon: "camera.aperture", value: ap)
                }
                if let sh = f.shutterDisplay {
                    infoChip(icon: "timer", value: sh)
                }
                if f.flashUsed {
                    infoChip(icon: "bolt.fill", value: L("Flash"))
                }
            }
            if let loc = f.locationName, !loc.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(loc)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(.white.opacity(0.9))
    }

    private var shareMenu: some View {
        VStack(spacing: 0) {
            shareMenuButton(
                icon: "square.and.arrow.down",
                title: L("Save Card to Photos")
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showShareMenu = false
                }
                Task { await saveCardToPhotos() }
            }
            Divider().background(.white.opacity(0.1))
            shareMenuButton(
                icon: "square.and.arrow.up",
                title: L("Export Card")
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showShareMenu = false
                }
                Task { await shareCard() }
            }
        }
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 16)
        .padding(.top, 52)
    }

    private func shareMenuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadCoverImage() async -> UIImage? {
        let name = roll.filmName.lowercased()
        guard let stock = FilmStock.allStocks.first(where: {
            $0.displayName.lowercased() == name ||
            "\($0.brand) \($0.name)".lowercased() == name ||
            $0.name.lowercased() == name
        }), let urlString = stock.githubCoverUrl, let url = URL(string: urlString)
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func renderCard(cover: UIImage?) -> UIImage? {
        guard let img = currentImage else { return nil }
        let card = PhotoShareCardView(
            image: img,
            coverImage: cover,
            frame: photoFrames[currentIndex],
            roll: roll
        )
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        renderer.scale = 1
        return renderer.uiImage
    }

    private func saveCardToPhotos() async {
        let cover = await loadCoverImage()
        guard let uiImage = renderCard(cover: cover) else { return }
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showSaveToast = true }
    }

    private func shareCard() async {
        let cover = await loadCoverImage()
        shareImage = renderCard(cover: cover)
    }

    private func saveRawPhotoToLibrary(_ assetID: String) {
        if !assetID.contains("/") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            if let img = UIImage(contentsOfFile: url.path) {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return }
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: nil
        ) { img, _ in
            guard let img else { return }
            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - ShareController
private struct ShareController: UIViewControllerRepresentable {
    let image: UIImage?
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let image, !context.coordinator.hasPresented else { return }
        context.coordinator.hasPresented = true
        let avc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        avc.completionWithItemsHandler = { _, _, _, _ in
            context.coordinator.hasPresented = false
            onComplete()
        }
        if let popover = avc.popoverPresentationController {
            popover.sourceView = uiViewController.view
        }
        uiViewController.present(avc, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hasPresented = false
    }
}

// MARK: - Photo Page View (single photo in album viewer)

private struct PhotoPageView: View {
    let frame: Frame
    let onDismiss: () -> Void
    @Binding var loadedImage: UIImage?
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3)) {
                                    if scale < 1.0 { scale = 1.0 }
                                    if scale > 5.0 { scale = 5.0 }
                                    lastScale = scale
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            } else if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .onAppear { loadImage() }
        .onDisappear { image = nil }
        .onChange(of: image) { _, new in loadedImage = new }
    }

    private func loadImage() {
        guard image == nil, let assetID = frame.photoAssetID else { return }

        let screenScale = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width * screenScale
        let screenHeight = UIScreen.main.bounds.height * screenScale
        let maxDimension = max(screenWidth, screenHeight)

        // Local file
        if !assetID.contains("/") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            DispatchQueue.global(qos: .userInitiated).async {
                guard let img = downsampledImage(at: url, maxPixel: maxDimension) else { return }
                DispatchQueue.main.async { self.image = img }
            }
            return
        }

        // PHAsset — request screen-sized, not maximum
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return }
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: maxDimension, height: maxDimension)
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { img, _ in
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}
