import SwiftUI

// MARK: - Import Source Sheet

struct ImportSourceSheet: View {
    let onPhotos: () -> Void
    let onCamera: () -> Void
    let onFiles: () -> Void
    let onDriveLink: () -> Void
    let slotsAvailable: Int

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            VStack(spacing: 2) {
                Text("Import Photos")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.filmText)
                HStack(spacing: 4) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                    Text("\(slotsAvailable) slot\(slotsAvailable == 1 ? "" : "s") available")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                }
                .padding(.top, 2)
            }
            .padding(.top, 18)

            LazyVGrid(columns: columns, spacing: 12) {
                importCard(
                    icon: "photo.on.rectangle",
                    title: "Photos",
                    color: Color(red: 0.2, green: 0.78, blue: 0.35),
                    action: onPhotos
                )
                importCard(
                    icon: "camera.fill",
                    title: "Camera",
                    color: Color(red: 1.0, green: 0.58, blue: 0.0),
                    action: onCamera
                )
                importCard(
                    icon: "folder.fill",
                    title: "Files",
                    color: Color(red: 0.0, green: 0.48, blue: 1.0),
                    action: onFiles
                )
                importCard(
                    icon: "link",
                    title: "Drive Link",
                    color: Color(red: 0.22, green: 0.73, blue: 0.29),
                    action: onDriveLink
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color.filmBackground)
    }

    private func importCard(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(height: 72)
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmText)
            }
        }
        .buttonStyle(.plain)
    }
}
