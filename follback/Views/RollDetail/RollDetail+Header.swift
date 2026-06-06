import SwiftUI

extension RollDetailView {

    // MARK: - Header
    var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.25)) {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.filmSurface)
                            .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                    )
            }
            Spacer()

            if hasPhotos {
                Button {
                    showImportOptions = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.filmText)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.filmSurface)
                                .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                        )
                }
            }

            Menu {
                Button { showEditDetails = true } label: { Label("Edit Details", systemImage: "pencil") }
                Button { showLightMeter = true } label: { Label("Light Meter", systemImage: "camera.metering.spot") }
                if hasPhotos {
                    Button { showContactSheet = true } label: { Label("Contact Sheet", systemImage: "film") }
                    Button { showCarouselCreator = true } label: { Label("Create Post", systemImage: "square.grid.3x1.below.line.grid.1x2") }
                    Button { showArGallery = true } label: { Label(L("AR Gallery"), systemImage: "arkit") }
                    Button {
                        withAnimation(.spring(response: 0.3)) { isSelectMode = true }
                    } label: { Label("Select Photos", systemImage: "checkmark.circle") }
                }
                if let driveLink = roll.driveFolderLink, !driveLink.isEmpty {
                    Button {
                        UIPasteboard.general.string = driveLink
                        Task { await showToast("Drive link copied") }
                    } label: { Label("Copy Drive Link", systemImage: "doc.on.doc") }
                }
                if roll.rollStatus == .inProgress || roll.rollStatus == .completed {
                    Button { markDeveloped() } label: { Label("Mark Developed", systemImage: "checkmark.seal") }
                }
                if roll.rollStatus != .inProgress {
                    Button { markInProgress() } label: { Label("Mark Active", systemImage: "play") }
                }
                Button { archiveRoll() } label: { Label("Archive", systemImage: "archivebox") }
                if isSelectMode && !selectedFrames.isEmpty {
                    Button(role: .destructive) { deleteSelectedPhotos() } label: { Label("Delete Selected (\(selectedFrames.count))", systemImage: "trash") }
                } else {
                    Button(role: .destructive) { showDeleteAlert = true } label: { Label("Delete Roll", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.filmSurface)
                            .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
