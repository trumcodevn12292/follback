import SwiftUI
import Photos

struct PhotoThumbnail: View {
    let assetID: String
    var targetSize: CGFloat = 200
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.filmSprocket
            }
        }
        .onAppear {
            if image == nil { loadImage() }
        }
        .onDisappear {
            image = nil
        }
    }

    private func loadImage() {
        let pixelSize = targetSize * UIScreen.main.scale
        if assetID.contains("_frame_") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            DispatchQueue.global(qos: .userInitiated).async {
                guard let uiImage = downsampledImage(at: url, maxPixel: pixelSize) else { return }
                DispatchQueue.main.async {
                    self.image = uiImage
                }
            }
            return
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let size = CGSize(width: pixelSize, height: pixelSize)
        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { uiImage, _ in
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }
    }
}

func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}
