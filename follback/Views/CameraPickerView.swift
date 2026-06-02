import SwiftUI
import Kingfisher

struct CameraPickerView: View {
    @Binding var selectedCameraName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredGroups: [(brand: String, models: [CameraModel])] {
        let groups = CameraModel.groupedByBrandPopularFirst
        if searchText.isEmpty { return groups }
        let query = searchText.lowercased()
        return groups.compactMap { group in
            let filtered = group.models.filter {
                $0.name.lowercased().contains(query) ||
                $0.brand.lowercased().contains(query) ||
                $0.displayName.lowercased().contains(query)
            }
            return filtered.isEmpty ? nil : (brand: group.brand, models: filtered)
        }
    }

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.filmSurface))
                    }
                    Spacer()
                    Text("Select Camera")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.filmText)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // No Selection option
                Button {
                    selectedCameraName = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("No Selection")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        if selectedCameraName == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.filmAccent)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider().background(Color.filmBorder.opacity(0.3))
                    .padding(.horizontal, 16)

                // Camera list
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(filteredGroups, id: \.brand) { group in
                            Section {
                                ForEach(group.models, id: \.id) { model in
                                    cameraRow(model)
                                    Divider().background(Color.filmBorder.opacity(0.2))
                                        .padding(.horizontal, 16)
                                }
                            } header: {
                                brandHeader(group.brand, models: group.models)
                            }
                        }
                    }
                    .padding(.bottom, 80)
                }

                // Search bar at bottom
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmTertiary)
                    TextField("Search cameras...", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.filmBorder.opacity(0.3), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func brandHeader(_ brand: String, models: [CameraModel]) -> some View {
        HStack(spacing: 10) {
            Text(brand)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.filmText)

            if let logoUrl = models.first?.fullBrandLogoUrl,
               let url = URL(string: logoUrl) {
                KFImage(url)
                    .requestModifier(FilmerImageAuth.shared.modifier)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.filmBackground)
    }

    private func cameraRow(_ model: CameraModel) -> some View {
        Button {
            selectedCameraName = model.displayName
            dismiss()
        } label: {
            HStack(spacing: 14) {
                // Camera cover image
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.filmSurfaceSecondary)
                        .frame(width: 56, height: 56)

                    if let coverUrl = model.fullCoverUrl,
                       let url = URL(string: coverUrl) {
                        KFImage(url)
                            .requestModifier(FilmerImageAuth.shared.modifier)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "camera")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color.filmTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.filmText)
                        .lineLimit(1)

                    if let type = model.cameraType {
                        Text(type)
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmTertiary)
                    }
                }

                Spacer()

                if selectedCameraName == model.displayName {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.filmAccent)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
