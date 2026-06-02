import SwiftUI
import SwiftData

struct CamerasView: View {
    @Query(sort: \Camera.name) var cameras: [Camera]
    @Query(sort: \Roll.createdAt, order: .reverse) var allRolls: [Roll]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCamera = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
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
                        withAnimation(.spring(response: 0.3)) {
                            showAddCamera = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.filmText)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.filmSurface)
                                    .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -20)
    }

    private var cameraList: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(cameras.enumerated()), id: \.element.id) { index, camera in
                let count = allRolls.filter { $0.camera?.id == camera.id }.count
                CameraRow(camera: camera, rollCount: count)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05), value: appeared)
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.filmAccent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "camera")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Color.filmAccent)
            }

            VStack(spacing: 8) {
                Text("No cameras yet")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)
                Text("Add your film cameras to start tracking rolls")
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                withAnimation(.spring(response: 0.35)) {
                    showAddCamera = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Camera")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.filmBackground)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.filmAccent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
    }
}

struct CameraRow: View {
    let camera: Camera
    let rollCount: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.filmAccent.opacity(0.08))
                    .frame(width: 52, height: 52)
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.filmAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(camera.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.filmText)
                Text("\(camera.filmFormat.displayName) \(camera.cameraType.displayName) · \(rollCount) rolls")
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmSecondary)
            }
            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
    }
}
