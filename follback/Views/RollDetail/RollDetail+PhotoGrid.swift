import SwiftUI
import UniformTypeIdentifiers

extension RollDetailView {

    // MARK: - Empty State
    var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(Color.filmTertiary.opacity(0.5))

                Text("No photos yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)

                Text("Import photos from your camera roll to fill this film roll")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.filmTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sort/Filter Bar
    var sortFilterBar: some View {
        HStack {
            let frames = roll.frames ?? []
            let photoCount = frames.filter { $0.photoAssetID != nil }.count
            Text("\(photoCount) photos")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.filmTertiary)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(L(roll.rollStatus.displayName))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(statusColor.opacity(0.1)))
        .overlay(Capsule().stroke(statusColor.opacity(0.2), lineWidth: 0.5))
    }

    var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .completed: return Color.filmSuccess
        case .developed: return Color.blue
        case .archived: return Color.filmTertiary
        }
    }

    // MARK: - Photo Grid (Filmer style - edge-to-edge)
    var photoGridColumns: [GridItem] {
        let count = hSizeClass == .regular ? 5 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: count)
    }

    var photoGrid: some View {
        let frames = (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }

        return VStack(spacing: 0) {
            if isSelectMode {
                selectModeBar(frames: frames)
            }

            LazyVGrid(columns: photoGridColumns, spacing: 2) {
                ForEach(frames, id: \.id) { frame in
                    GeometryReader { geo in
                        photoCell(frame: frame, size: geo.size.width)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .onDrag {
                        draggedFrame = frame
                        return NSItemProvider(object: frame.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: PhotoDropDelegate(
                        frame: frame,
                        roll: roll,
                        draggedFrame: $draggedFrame,
                        modelContext: modelContext
                    ))
                }
            }
            .padding(.horizontal, 0)
        }
    }

    func selectModeBar(frames: [Frame]) -> some View {
        HStack(spacing: 12) {
            Button("Select All") {
                selectedFrames = Set(frames.map { $0.id })
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.filmAccent)

            Spacer()

            Text("\(selectedFrames.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.filmTertiary)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3)) {
                    isSelectMode = false
                    selectedFrames.removeAll()
                }
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.filmSurface)
    }

    func photoCell(frame: Frame, size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let assetID = frame.photoAssetID {
                    PhotoThumbnail(assetID: assetID)
                        .frame(width: size, height: size)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.filmSurface)
                        .frame(width: size, height: size)
                }
            }

            if isSelectMode {
                ZStack {
                    Circle()
                        .fill(selectedFrames.contains(frame.id) ? Color.filmAccent : Color.black.opacity(0.4))
                        .frame(width: 24, height: 24)
                    if selectedFrames.contains(frame.id) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectMode {
                if selectedFrames.contains(frame.id) {
                    selectedFrames.remove(frame.id)
                } else {
                    selectedFrames.insert(frame.id)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                fullScreenFrame = frame
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
        .contextMenu {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                fullScreenFrame = frame
            } label: {
                Label(L("View Full Screen"), systemImage: "arrow.up.left.and.arrow.down.right")
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                savePhotoToCameraRoll(frame)
            } label: {
                Label(L("Save to Photos"), systemImage: "square.and.arrow.down")
            }
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.3)) {
                    isSelectMode = true
                    selectedFrames.insert(frame.id)
                }
            } label: {
                Label(L("Select"), systemImage: "checkmark.circle")
            }
        }
    }
}
