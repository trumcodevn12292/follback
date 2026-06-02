import SwiftUI
import Photos

struct FrameViewerView: View {
    let frame: Frame
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var showInfo = true
    @State private var showDarkroom = false
    @State private var showShare = false
    @State private var isToastVisible = false

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
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.filmTertiary, Color.filmTertiary.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text("No photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                }
            }

            if showInfo {
                VStack {
                    HStack(spacing: 16) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.filmText)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().stroke(Color.filmBorder.opacity(0.5), lineWidth: 0.5))
                                )
                        }
                        Spacer()
                        if image != nil {
                            Button {
                                showDarkroom = true
                            } label: {
                                Image(systemName: "wand.and.stars.inverse")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.filmText)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Circle().stroke(Color.filmBorder.opacity(0.5), lineWidth: 0.5))
                                    )
                            }
                            Button {
                                showShare = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.filmText)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Circle().stroke(Color.filmBorder.opacity(0.5), lineWidth: 0.5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

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
                    displayToast()
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = image, let roll = frame.roll {
                ShareTemplateView(image: img, frame: frame, roll: roll)
            }
        }
        .overlay {
            if isToastVisible {
                toastView
            }
        }
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Frame #\(frame.number) · \(frame.roll?.filmName ?? "")")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)

            if let camera = frame.roll?.camera {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.filmAccent)
                    Text("\(camera.name) · \(frame.capturedAt ?? Date(), style: .date)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                }
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
                    infoChip(text: "Flash", icon: "bolt.fill")
                }
            }

            if !frame.notes.isEmpty {
                Text(frame.notes)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.clear, Color.filmBackground.opacity(0.9), Color.filmBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func infoChip(text: String, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(Color.filmText)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.filmBorder.opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    private var toastView: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.filmSuccess)
                Text("Saved to Photos")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.filmSurface.opacity(0.8))
                    )
                    .overlay(Capsule().stroke(Color.filmBorder, lineWidth: 0.5))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
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

    private func displayToast() {
        withAnimation(.spring(response: 0.3)) {
            isToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                isToastVisible = false
            }
        }
    }
}
