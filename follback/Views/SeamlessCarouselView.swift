import SwiftUI
import Photos

struct SeamlessCarouselView: View {
    let roll: Roll
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var selectedPhotos: Set<Int> = []
    @State private var isLoading = true
    @State private var slideCount = 3
    @State private var isSaving = false
    @State private var savedToPhotos = false
    @State private var currentPreviewSlide = 0

    private let slideRatio: CGFloat = 4.0 / 5.0

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
            // Background gradient
            LinearGradient(
                colors: [Color.filmBackground, Color.filmSurfaceSecondary, Color.filmBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Carousel preview
                        carouselPreview
                            .padding(.horizontal, 16)

                        // Controls
                        controlSection
                            .padding(.horizontal, 16)

                        // Photo selector
                        photoSelector
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 40)
                }
            }

            // Toast
            if savedToPhotos {
                VStack {
                    Spacer()
                    toastBanner
                        .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { loadAllImages() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.filmSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.filmSurface.opacity(0.5)))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("CREATE POST")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.filmText)
                    .kerning(2)
                Text("Seamless Carousel")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.filmCopper)
            }
            Spacer()
            Button { saveCarousel() } label: {
                if isSaving {
                    ProgressView().tint(Color.filmSecondary).frame(width: 34, height: 34)
                } else {
                    Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "arrow.down.to.line")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(savedToPhotos ? .green : Color.filmCopper)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.filmCopper.opacity(0.15)))
                }
            }
            .disabled(isSaving || orderedSelected.count < 2)
        }
    }

    // MARK: - Carousel Preview

    private var carouselPreview: some View {
        VStack(spacing: 10) {
            if orderedSelected.count >= 2 {
                let slideWidth: CGFloat = UIScreen.main.bounds.width - 64
                let slideHeight = slideWidth * (5.0 / 4.0)

                // Preview with page indicator
                    TabView(selection: $currentPreviewSlide) {
                        ForEach(0..<slideCount, id: \.self) { index in
                            slidePreview(index: index, totalSlides: slideCount, slideSize: CGSize(width: slideWidth, height: slideHeight))
                                .frame(width: slideWidth, height: slideHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.filmCopper.opacity(0.15), radius: 20, y: 8)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: slideHeight + 16)

                    // Custom page dots
                    HStack(spacing: 6) {
                        ForEach(0..<slideCount, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPreviewSlide ? Color.filmCopper : Color.filmBorderActive.opacity(0.5))
                                .frame(width: index == currentPreviewSlide ? 16 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: currentPreviewSlide)
                        }
                    }

                    // Info label
                    Text("Swipe to preview slides • \(slideCount) slides from \(orderedSelected.count) photos")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                } else {
                    // Empty state
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.filmSurface.opacity(0.3))
                        .frame(height: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.filmCopper.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.filmCopper.opacity(0.1))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "rectangle.split.3x1")
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundColor(Color.filmCopper)
                                }
                                Text("Select at least 2 photos")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.filmSecondary)
                                Text("Photos will be stitched into a seamless carousel")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color.filmTertiary)
                            }
                        )
            }
        }
    }

    @ViewBuilder
    private func slidePreview(index: Int, totalSlides: Int, slideSize: CGSize) -> some View {
        let images = orderedSelected.compactMap { loadedImages[$0] }
        if images.isEmpty {
            Color.filmSurfaceSecondary
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

    // MARK: - Controls

    private var controlSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("SLIDES")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.filmTertiary)
                    .kerning(2)
                Spacer()
                Text("\(slideCount) slides")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.filmCopper)
            }

            // Slider-style control
            HStack(spacing: 8) {
                ForEach([2, 3, 4, 5, 6, 7, 8, 9, 10], id: \.self) { count in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            slideCount = count
                            currentPreviewSlide = 0
                        }
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 12, weight: slideCount == count ? .bold : .medium, design: .rounded))
                            .foregroundColor(slideCount == count ? Color.filmBackground : Color.filmSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                Capsule().fill(slideCount == count ? Color.filmCopper : Color.filmSurface.opacity(0.5))
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface.opacity(0.3))
        )
    }

    // MARK: - Photo Selector

    private var photoSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("PHOTOS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.filmTertiary)
                    .kerning(2)

                if !selectedPhotos.isEmpty {
                    Text("\(orderedSelected.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color.filmBackground)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.filmCopper))
                }

                Spacer()

                if !selectedPhotos.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedPhotos.removeAll() }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.filmCopper)
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: hSizeClass == .regular ? 6 : 4), spacing: 3) {
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
                            Color.filmSurfaceSecondary
                                .aspectRatio(1, contentMode: .fill)
                                .overlay(
                                    ProgressView().tint(Color.filmTertiary)
                                )
                        }

                        if isSelected, let idx = selectionIndex {
                            Text("\(idx + 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(Color.filmBackground)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.filmCopper))
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                .padding(4)
                        }

                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.filmCopper, lineWidth: 2.5)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .scaleEffect(isSelected ? 0.95 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
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

    // MARK: - Toast

    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.filmSuccess)
            Text("\(slideCount) slides saved to Photos")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.filmText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Color.filmSurface)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
    }

    // MARK: - Load

    private func loadAllImages() {
        let frames = photoFrames
        Task.detached(priority: .userInitiated) {
            for frame in frames {
                guard let assetID = frame.photoAssetID else { continue }

                if !assetID.contains("/") {
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
            let slideHeight: CGFloat = 1350
            let totalWidth = slideWidth * CGFloat(currentSlideCount)

            let stitchedRenderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: slideHeight))
            let stitched = stitchedRenderer.image { _ in
                let segmentWidth = totalWidth / CGFloat(images.count)
                for (i, img) in images.enumerated() {
                    let scaledHeight = slideHeight
                    let scaledWidth = img.size.width * (scaledHeight / img.size.height)
                    let x = CGFloat(i) * segmentWidth + (segmentWidth - scaledWidth) / 2.0
                    img.draw(in: CGRect(x: x, y: 0, width: scaledWidth, height: scaledHeight))
                }
            }

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
                withAnimation(.spring(response: 0.4)) { savedToPhotos = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { savedToPhotos = false }
                }
            }
        }
    }
}
