import SwiftUI
import Photos

struct SeamlessCarouselView: View {
    let roll: Roll
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var selectedPhotos: Set<Int> = []
    @State private var isLoading = true
    @State private var slideCount = 3
    @State private var isSaving = false
    @State private var savedToPhotos = false
    @State private var previewOffset: CGFloat = 0

    private let slideRatio: CGFloat = 4.0 / 5.0 // Instagram portrait

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    private var orderedSelected: [Int] {
        photoFrames.filter { selectedPhotos.contains($0.number) }.map(\.number)
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0908").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    Spacer()
                    Text("CREATE POST")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .kerning(2)
                    Spacer()
                    Button { saveCarousel() } label: {
                        if isSaving {
                            ProgressView().tint(.white).frame(width: 36, height: 36)
                        } else {
                            Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(savedToPhotos ? .green : .white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                    }
                    .disabled(isSaving || orderedSelected.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Carousel preview
                        carouselPreview
                            .padding(.horizontal, 16)

                        // Slide count control
                        slideCountControl
                            .padding(.horizontal, 16)

                        // Photo selector
                        photoSelector
                            .padding(.horizontal, 16)
                    }
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
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: "#2A2A2A")))
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { loadAllImages() }
    }

    // MARK: - Carousel Preview

    private var carouselPreview: some View {
        VStack(spacing: 8) {
            Text("PREVIEW")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(hex: "#6A6A6A"))
                .kerning(2)

            if orderedSelected.count >= 2 {
                let slideWidth: CGFloat = UIScreen.main.bounds.width - 32
                let slideHeight = slideWidth * (5.0 / 4.0)
                let totalWidth = slideWidth * CGFloat(slideCount)

                GeometryReader { _ in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(0..<slideCount, id: \.self) { index in
                                slidePreview(index: index, totalSlides: slideCount, slideSize: CGSize(width: slideWidth, height: slideHeight))
                                    .frame(width: slideWidth, height: slideHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
                .frame(height: slideHeight)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 32, weight: .light))
                                .foregroundColor(Color(hex: "#4A4A4A"))
                            Text("Select at least 2 photos")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#6A6A6A"))
                        }
                    )
            }
        }
    }

    @ViewBuilder
    private func slidePreview(index: Int, totalSlides: Int, slideSize: CGSize) -> some View {
        let images = orderedSelected.compactMap { loadedImages[$0] }
        if images.isEmpty {
            Color(hex: "#1A1A1A")
        } else {
            Canvas { context, size in
                let stitchedWidth = size.width * CGFloat(totalSlides)
                let stitchedHeight = size.height
                let imageCount = images.count
                let segmentWidth = stitchedWidth / CGFloat(imageCount)

                for (i, img) in images.enumerated() {
                    let imgSize = img.size
                    let scaledHeight = stitchedHeight
                    let scaledWidth = imgSize.width * (scaledHeight / imgSize.height)
                    let imgX = CGFloat(i) * segmentWidth + (segmentWidth - scaledWidth) / 2.0
                    let sourceRect = CGRect(x: imgX, y: 0, width: scaledWidth, height: scaledHeight)

                    let visibleX = CGFloat(index) * size.width
                    let visibleRect = CGRect(x: visibleX, y: 0, width: size.width, height: size.height)
                    let intersection = sourceRect.intersection(visibleRect)

                    guard !intersection.isNull else { continue }

                    let srcCropX = (intersection.minX - imgX) / scaledWidth * imgSize.width
                    let srcCropW = intersection.width / scaledWidth * imgSize.width
                    let srcCropRect = CGRect(x: srcCropX, y: 0, width: srcCropW, height: imgSize.height)

                    guard let cgImage = img.cgImage,
                          let cropped = cgImage.cropping(to: srcCropRect) else { continue }

                    let destX = intersection.minX - visibleX
                    let destRect = CGRect(x: destX, y: 0, width: intersection.width, height: size.height)
                    context.draw(Image(uiImage: UIImage(cgImage: cropped)), in: destRect)
                }
            }
        }
    }

    // MARK: - Slide Count

    private var slideCountControl: some View {
        VStack(spacing: 8) {
            Text("SLIDES")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(hex: "#6A6A6A"))
                .kerning(2)

            HStack(spacing: 12) {
                ForEach([2, 3, 4, 5, 6, 7, 8, 9, 10], id: \.self) { count in
                    Button {
                        withAnimation(.spring(response: 0.3)) { slideCount = count }
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 13, weight: slideCount == count ? .bold : .regular, design: .monospaced))
                            .foregroundColor(slideCount == count ? .white : Color(hex: "#6A6A6A"))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(slideCount == count ? Color(hex: "#C86B28") : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Photo Selector

    private var photoSelector: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PHOTOS (\(orderedSelected.count))")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "#6A6A6A"))
                    .kerning(2)
                Spacer()
                if !selectedPhotos.isEmpty {
                    Button {
                        withAnimation { selectedPhotos.removeAll() }
                    } label: {
                        Text("CLEAR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#C86B28"))
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 2) {
                ForEach(photoFrames, id: \.id) { frame in
                    let isSelected = selectedPhotos.contains(frame.number)
                    let selectionIndex = orderedSelected.firstIndex(of: frame.number)

                    ZStack(alignment: .topTrailing) {
                        if let img = loadedImages[frame.number] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        } else {
                            Color(hex: "#1A1A1A")
                                .aspectRatio(1, contentMode: .fill)
                                .overlay(
                                    ProgressView().tint(Color(hex: "#4A4A4A"))
                                )
                        }

                        if isSelected, let idx = selectionIndex {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color(hex: "#C86B28")))
                                .padding(4)
                        }

                        if isSelected {
                            Color.white.opacity(0.1)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(isSelected ? Color(hex: "#C86B28") : Color.clear, lineWidth: 2)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2)) {
                            if isSelected {
                                selectedPhotos.remove(frame.number)
                            } else {
                                selectedPhotos.insert(frame.number)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Load

    private func loadAllImages() {
        let frames = photoFrames
        Task.detached(priority: .userInitiated) {
            for frame in frames {
                guard let assetID = frame.photoAssetID else { continue }

                if assetID.contains("_frame_") {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent(assetID)
                    let img = autoreleasepool {
                        downsampledImage(at: url, maxPixel: 800)
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

                let targetSize = CGSize(width: 800, height: 800)
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

    // MARK: - Save Carousel

    private func saveCarousel() {
        guard orderedSelected.count >= 2 else { return }
        isSaving = true

        let images = orderedSelected.compactMap { loadedImages[$0] }
        guard images.count >= 2 else {
            isSaving = false
            return
        }

        let currentSlideCount = slideCount
        Task.detached(priority: .userInitiated) {
            let slideWidth: CGFloat = 1080
            let slideHeight: CGFloat = 1350 // 4:5 Instagram
            let totalWidth = slideWidth * CGFloat(currentSlideCount)

            // Stitch all selected images into one wide canvas
            let stitchedRenderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: slideHeight))
            let stitched = stitchedRenderer.image { ctx in
                let segmentWidth = totalWidth / CGFloat(images.count)
                for (i, img) in images.enumerated() {
                    let scaledHeight = slideHeight
                    let scaledWidth = img.size.width * (scaledHeight / img.size.height)
                    let x = CGFloat(i) * segmentWidth + (segmentWidth - scaledWidth) / 2.0
                    img.draw(in: CGRect(x: x, y: 0, width: scaledWidth, height: scaledHeight))
                }
            }

            // Slice into individual slides
            var slides: [UIImage] = []
            for i in 0..<currentSlideCount {
                autoreleasepool {
                    let cropRect = CGRect(
                        x: CGFloat(i) * slideWidth * stitched.scale,
                        y: 0,
                        width: slideWidth * stitched.scale,
                        height: slideHeight * stitched.scale
                    )
                    if let cgCrop = stitched.cgImage?.cropping(to: cropRect) {
                        slides.append(UIImage(cgImage: cgCrop))
                    }
                }
            }

            // Save each slide to Photos
            for slide in slides {
                await withCheckedContinuation { continuation in
                    PHPhotoLibrary.shared().performChanges {
                        guard let data = slide.jpegData(compressionQuality: 0.95) else { return }
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: data, options: nil)
                    } completionHandler: { _, _ in
                        continuation.resume()
                    }
                }
            }

            await MainActor.run {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.4)) { savedToPhotos = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { savedToPhotos = false }
                }
            }
        }
    }
}
