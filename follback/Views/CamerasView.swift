import SwiftUI
import SwiftData
import Kingfisher

struct CamerasView: View {
    @Query(sort: \Camera.name) var cameras: [Camera]
    @Query(sort: \Roll.createdAt, order: .reverse) var allRolls: [Roll]
    @Environment(\.modelContext) private var modelContext

    @State private var appeared = false
    @State private var searchText = ""
    @State private var showAddCamera = false

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
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("CAMERAS")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(Color.filmText)
                        .kerning(1.5)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)
                .animation(.easeOut(duration: 0.3), value: appeared)

                // My cameras section
                if !cameras.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MY CAMERAS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(cameras) { camera in
                                    myCameraCard(camera)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 16)
                }

                // Search bar
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
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Camera database list
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(filteredGroups, id: \.brand) { group in
                            Section {
                                ForEach(group.models, id: \.id) { model in
                                    Button {
                                        addCameraFromModel(model)
                                    } label: {
                                        apiCameraRow(model)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().background(Color.filmBorder.opacity(0.2))
                                        .padding(.horizontal, 16)
                                }
                            } header: {
                                brandHeader(group.brand, models: group.models)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    appeared = true
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private func myCameraCard(_ camera: Camera) -> some View {
        let model = CameraModel.allModels.first { m in
            m.name.lowercased() == camera.name.lowercased() &&
            m.brand.lowercased() == camera.brand.lowercased()
        } ?? CameraModel.allModels.first { m in
            camera.name.lowercased().contains(m.name.lowercased())
        }
        let rollCount = allRolls.filter { $0.camera?.id == camera.id }.count

        return VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.filmSurfaceSecondary)
                    .frame(width: 72, height: 72)

                if let coverUrl = model?.fullCoverUrl, let url = URL(string: coverUrl) {
                    KFImage(url)
                        .requestModifier(FilmerImageAuth.shared.modifier)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "camera")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(Color.filmTertiary)
                }
            }

            Text(camera.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.filmText)
                .lineLimit(1)
            Text("\(rollCount) rolls")
                .font(.system(size: 10))
                .foregroundColor(Color.filmTertiary)
        }
        .frame(width: 90)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface)
        )
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

    private func apiCameraRow(_ model: CameraModel) -> some View {
        let isAdded = cameras.contains { c in
            c.name.lowercased() == model.name.lowercased() &&
            c.brand.lowercased() == model.brand.lowercased()
        }

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.filmSurfaceSecondary)
                    .frame(width: 56, height: 56)

                if let coverUrl = model.fullCoverUrl, let url = URL(string: coverUrl) {
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

            if isAdded {
                Text("Added")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.filmAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.filmAccent.opacity(0.15))
                    )
            } else {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color.filmAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func addCameraFromModel(_ model: CameraModel) {
        let alreadyExists = cameras.contains { c in
            c.name.lowercased() == model.name.lowercased() &&
            c.brand.lowercased() == model.brand.lowercased()
        }
        guard !alreadyExists else { return }

        let camera = Camera(
            name: model.name,
            brand: model.brand,
            filmFormat: .mm35,
            cameraType: .pointAndShoot
        )
        modelContext.insert(camera)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
