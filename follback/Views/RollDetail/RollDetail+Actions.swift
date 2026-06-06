import SwiftUI
import SwiftData
import Photos

extension RollDetailView {

    func markDeveloped() {
        roll.updateStatus(.developed)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func markInProgress() {
        roll.updateStatus(.inProgress)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func archiveRoll() {
        roll.updateStatus(.archived)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    func deleteSelectedPhotos() {
        let frames = roll.frames ?? []
        let toDelete = frames.filter { selectedFrames.contains($0.id) }
        for frame in toDelete {
            if let assetID = frame.photoAssetID {
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docsDir.appendingPathComponent(assetID)
                try? FileManager.default.removeItem(at: fileURL)
            }
            modelContext.delete(frame)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        withAnimation(.spring(response: 0.3)) {
            isSelectMode = false
            selectedFrames.removeAll()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func savePhotoToCameraRoll(_ frame: Frame) {
        guard let assetID = frame.photoAssetID else { return }
        if !assetID.contains("/") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            if let img = UIImage(contentsOfFile: url.path) {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                Task { await showToast("Saved to Photos") }
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
                Task { await MainActor.run { toastMessage = L("Saved to Photos"); withAnimation { showToastFlag = true } } }
        }
    }
}
