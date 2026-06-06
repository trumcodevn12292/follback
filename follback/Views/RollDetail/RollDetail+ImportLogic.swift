import SwiftUI
import SwiftData
import PhotosUI
import Photos

extension RollDetailView {

    // MARK: - Photo Import (from Photo Library)
    func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        var importedCount = 0
        let importMode = UserDefaults.standard.string(forKey: "photoImportMode") ?? "Copy"
        let shouldUploadToDrive = driveService.isSignedIn

        for (index, item) in items.enumerated() {
            guard index < emptySlots.count else { break }
            let slotNumber = emptySlots[index]

            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
                let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? jpegData.write(to: url)

                if importMode == "Reference" {
                    saveToPhotoAlbum(data: jpegData)
                }

                if shouldUploadToDrive {
                    Task { await driveService.uploadPhoto(data: jpegData, filename: "FilmVault/\(roll.filmName)/frame_\(slotNumber).jpg") }
                }

                if let existingFrame = frames.first(where: { $0.number == slotNumber }) {
                    existingFrame.photoAssetID = filename
                } else {
                    let newFrame = Frame(number: slotNumber, photoAssetID: filename)
                    newFrame.roll = roll
                    modelContext.insert(newFrame)
                }
                importedCount += 1
            }
        }

        await finishImport(count: importedCount)
    }

    // MARK: - Import from Files

    func importFromFiles(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, !urls.isEmpty else { return }

        let imageURLs = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "webp"].contains(ext)
        }

        guard !imageURLs.isEmpty else {
            await showToast("No images found in selection")
            return
        }

        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        guard !emptySlots.isEmpty else {
            await showToast("No empty slots available")
            return
        }

        var importedCount = 0
        let importMode = UserDefaults.standard.string(forKey: "photoImportMode") ?? "Copy"
        let shouldUploadToDrive = driveService.isSignedIn

        for (index, url) in imageURLs.enumerated() {
            guard index < emptySlots.count else { break }
            let slotNumber = emptySlots[index]

            autoreleasepool {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                guard let data = try? Data(contentsOf: url),
                      let uiImage = UIImage(data: data),
                      let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }

                let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
                let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? jpegData.write(to: destURL)

                if importMode == "Reference" {
                    saveToPhotoAlbum(data: jpegData)
                }

                if shouldUploadToDrive {
                    Task { await driveService.uploadPhoto(data: jpegData, filename: "FilmVault/\(roll.filmName)/frame_\(slotNumber).jpg") }
                }

                if let existingFrame = frames.first(where: { $0.number == slotNumber }) {
                    existingFrame.photoAssetID = filename
                } else {
                    let newFrame = Frame(number: slotNumber, photoAssetID: filename)
                    newFrame.roll = roll
                    modelContext.insert(newFrame)
                }
                importedCount += 1
            }
        }

        await finishImport(count: importedCount)
    }

    // MARK: - Import from Google Drive Link

    func importFromDriveLink(_ link: String) async {
        guard !link.isEmpty else { return }
        await MainActor.run { isImporting = true }

        let downloaded = await driveService.downloadFromLink(link)
        guard !downloaded.isEmpty else {
            await showToast("No images found at link")
            return
        }

        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        var importedCount = 0
        let shouldUploadToDrive = driveService.isSignedIn

        for (index, file) in downloaded.enumerated() {
            guard index < emptySlots.count else { break }
            let slotNumber = emptySlots[index]

            autoreleasepool {
                guard let uiImage = UIImage(data: file.data),
                      let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }

                let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
                let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? jpegData.write(to: destURL)

                if shouldUploadToDrive {
                    Task { await driveService.uploadPhoto(data: jpegData, filename: "FilmVault/\(roll.filmName)/frame_\(slotNumber).jpg") }
                }

                if let existingFrame = frames.first(where: { $0.number == slotNumber }) {
                    existingFrame.photoAssetID = filename
                } else {
                    let newFrame = Frame(number: slotNumber, photoAssetID: filename)
                    newFrame.roll = roll
                    modelContext.insert(newFrame)
                }
                importedCount += 1
            }
        }

        await finishImport(count: importedCount)
    }

    // MARK: - Helpers

    func saveToPhotoAlbum(data: Data) {
        // No longer duplicating photos — Reference mode now links directly
        // This function is kept for backward compatibility but is a no-op
    }

    func finishImport(count: Int) async {
        if count > 0 {
            roll.checkAutoComplete()
            try? modelContext.save()
            NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
                let completed = roll.isCompleted
                toastMessage = completed
                    ? "Roll complete! \(count) photo\(count == 1 ? "" : "s") imported"
                    : "Imported \(count) photo\(count == 1 ? "" : "s")"
                withAnimation(.easeOut(duration: 0.3)) { showToastFlag = true }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) { showToastFlag = false }
            }
        } else {
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
            }
        }
    }

    func showToast(_ message: String) async {
        await MainActor.run {
            isImporting = false
            toastMessage = message
            withAnimation(.easeOut(duration: 0.3)) { showToastFlag = true }
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.3)) { showToastFlag = false }
        }
    }

    // MARK: - Upload to Google Drive

    func uploadSelectedToDrive(frames: [Frame]) async {
        guard driveService.isSignedIn, !selectedFrames.isEmpty else { return }
        await MainActor.run { isUploadingToDrive = true }

        let folderName = roll.filmName
        let folderId = await driveService.createFolder(name: folderName)

        let framesToUpload = frames.filter { selectedFrames.contains($0.id) }
        var uploadedCount = 0

        for frame in framesToUpload {
            guard let assetID = frame.photoAssetID else { continue }
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsDir.appendingPathComponent(assetID)
            guard let data = try? Data(contentsOf: fileURL) else { continue }

            let filename = "frame_\(frame.number).jpg"
            _ = await driveService.uploadPhoto(data: data, filename: filename, folderId: folderId)
            uploadedCount += 1
        }

        if let folderId = folderId {
            let driveLink = "https://drive.google.com/drive/folders/\(folderId)"
            await MainActor.run {
                roll.driveFolderLink = driveLink
                try? modelContext.save()
                NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
            }
        }

        await MainActor.run {
            isUploadingToDrive = false
            isSelectMode = false
            selectedFrames.removeAll()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        await showToast("Uploaded \(uploadedCount) photo\(uploadedCount == 1 ? "" : "s") to Drive")
    }

    // MARK: - Camera Import

    func importCameraPhoto(_ image: UIImage) async {
        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }
        guard let slotNumber = emptySlots.first else {
            await showToast("No empty slots available")
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.9) else { return }
        let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? jpegData.write(to: url)

        let importMode = UserDefaults.standard.string(forKey: "photoImportMode") ?? "Copy"
        if importMode == "Reference" {
            saveToPhotoAlbum(data: jpegData)
        }

        if let existingFrame = frames.first(where: { $0.number == slotNumber }) {
            existingFrame.photoAssetID = filename
        } else {
            let newFrame = Frame(number: slotNumber, photoAssetID: filename)
            newFrame.roll = roll
            modelContext.insert(newFrame)
        }

        await finishImport(count: 1)
    }
}
