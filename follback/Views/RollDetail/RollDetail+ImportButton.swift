import SwiftUI

extension RollDetailView {

    // MARK: - Import Button (bottom floating)
    var importButton: some View {
        Button {
            if isSelectMode && driveService.isSignedIn && !selectedFrames.isEmpty {
                let frames = (roll.frames ?? []).filter { $0.photoAssetID != nil }.sorted { $0.number < $1.number }
                Task { await uploadSelectedToDrive(frames: frames) }
            } else if !isImporting && !isSelectMode {
                showImportOptions = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } label: {
            HStack(spacing: 8) {
                if isImporting || isUploadingToDrive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.filmBackground))
                        .scaleEffect(0.8)
                    Text(isUploadingToDrive ? "Uploading..." : "Importing...")
                        .font(.system(size: 16, weight: .semibold))
                } else if isSelectMode && driveService.isSignedIn && !selectedFrames.isEmpty {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                    Text("Upload to Drive")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                    Text("Import Photos")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: 220)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.filmAccent)
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelectMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedFrames.count)
        }
        .disabled(isImporting || isUploadingToDrive || (emptySlotCount == 0 && !isSelectMode))
        .opacity((emptySlotCount == 0 && !isImporting && !isSelectMode) ? 0.5 : 1)
        .padding(.bottom, 30)
    }

    // MARK: - Toast
    func toastView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.filmSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text("Import complete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmText)
                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.filmSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 90)
    }
}
