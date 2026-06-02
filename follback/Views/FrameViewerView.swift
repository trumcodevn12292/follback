import SwiftUI
import Photos
import Kingfisher

struct FrameViewerView: View {
    let frame: Frame
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var showInfo = true
    @State private var showDarkroom = false
    @State private var showShare = false
    @State private var showToast = false

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showInfo.toggle()
                        }
                    }
            } else if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(Color.filmTertiary)
                    Text("No photo")
                        .foregroundColor(Color.filmSecondary)
                }
            }

            if showInfo {
                VStack {
                    HStack(spacing: 16) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color.filmText.opacity(0.8))
                        }
                        Spacer()
                        if image != nil {
                            Button {
                                showDarkroom = true
                            } label: {
                                Image(systemName: "wand.and.stars.inverse")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color.filmText.opacity(0.8))
                            }
                            Button {
                                showShare = true
                            } label: {
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color.filmText.opacity(0.8))
                            }
                        }
                    }
                    .padding()

                    Spacer()

                    infoPanel
                }
            }
        }
        .onAppear {
            loadFullImage()
        }
        .sheet(isPresented: $showDarkroom) {
            if let img = image {
                DarkroomView(image: img) { _ in
                    showToast("Applied filter")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = image, let roll = frame.roll {
                ShareTemplateView(image: img, frame: frame, roll: roll)
            }
        }
        .overlay {
            if showToast {
                toastView
            }
        }
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frame #\(frame.number) · \(frame.roll?.filmName ?? "")")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.filmText)

            if let camera = frame.roll?.camera {
                Text("\(camera.name) · \(frame.capturedAt ?? Date(), style: .date)")
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmSecondary)
            }

            HStack(spacing: 8) {
                if let ap = frame.apertureDisplay {
                    infoChip(text: ap)
                }
                if let sh = frame.shutterDisplay {
                    infoChip(text: sh)
                }
                if let focus = frame.focusDistance {
                    infoChip(text: focus)
                }
                if frame.flashUsed {
                    infoChip(text: "Flash")
                }
            }

            if !frame.notes.isEmpty {
                Text(frame.notes)
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmSecondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, Color.filmBackground.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func infoChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(Color.filmText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.filmSurface)
            )
    }

    private var toastView: some View {
        VStack {
            Spacer()
            Text("Saved to Photos")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.filmSurface)
                        .overlay(Capsule().stroke(Color.filmBorder, lineWidth: 1))
                )
                .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func loadFullImage() {
        guard let assetID = frame.photoAssetID else { return }
        if assetID.contains("_frame_") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
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
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        manager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { uiImage, _ in
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                showToast = false
            }
        }
    }
}
