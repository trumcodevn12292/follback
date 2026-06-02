import SwiftUI
import SwiftData
import Kingfisher

struct CamerasView: View {
    @Query(sort: \Camera.name) var cameras: [Camera]
    @Query(sort: \Roll.createdAt, order: .reverse) var allRolls: [Roll]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCamera = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection

                    if cameras.isEmpty {
                        emptyState
                    } else {
                        cameraList
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCamera = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.filmAccent)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.filmAccent.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showAddCamera) {
                NavigationStack {
                    AddCameraView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    appeared = true
                }
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cameras")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)

            Text("\(cameras.count) cameras · \(allRolls.count) rolls")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

    private var cameraList: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(cameras.enumerated()), id: \.element.id) { index, camera in
                let count = allRolls.filter { $0.camera?.id == camera.id }.count
                CameraRow(camera: camera, rollCount: count)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.04), value: appeared)
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(Color.filmTertiary)

            VStack(spacing: 6) {
                Text("No cameras yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.filmText)
                Text("Add your film cameras")
                    .font(.system(size: 15))
                    .foregroundColor(Color.filmTertiary)
            }

            Button {
                showAddCamera = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Text("Add Camera")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmBackground)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.filmAccent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 80)
    }
}

struct CameraRow: View {
    let camera: Camera
    let rollCount: Int

    private var matchingCameraModel: CameraModel? {
        CameraModel.allModels.first { model in
            model.name.lowercased() == camera.name.lowercased() &&
            model.brand.lowercased() == camera.brand.lowercased()
        } ?? CameraModel.allModels.first { model in
            camera.name.lowercased().contains(model.name.lowercased())
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.filmSurfaceSecondary)
                    .frame(width: 48, height: 48)

                if let model = matchingCameraModel,
                   let coverUrlString = model.fullCoverUrl,
                   let coverURL = URL(string: coverUrlString) {
                    KFImage(coverURL)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "camera")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(Color.filmTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(camera.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmText)
                HStack(spacing: 6) {
                    Text(camera.filmFormat.displayName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.filmAccent)
                    Text("·")
                        .foregroundColor(Color.filmTertiary)
                    Text(camera.cameraType.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(Color.filmSecondary)
                    Text("·")
                        .foregroundColor(Color.filmTertiary)
                    Text("\(rollCount) rolls")
                        .font(.system(size: 11))
                        .foregroundColor(Color.filmSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.filmTertiary.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                )
        )
    }
}
