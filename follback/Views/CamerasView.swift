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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.filmAccent, Color.filmGold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.filmSurface)
                                    .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Cameras")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.filmText, Color.filmText.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.system(size: 12))
                    .foregroundColor(Color.filmAccent)
                Text("\(cameras.count) cameras")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)
                Text("·")
                    .foregroundColor(Color.filmTertiary)
                Text("\(allRolls.count) rolls")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)
            }
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
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.filmAccent.opacity(0.1), Color.filmAccent.opacity(0.02)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .stroke(Color.filmAccent.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Image(systemName: "camera")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("No cameras yet")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)
                Text("Add your film cameras to\nstart tracking rolls")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                withAnimation(.spring(response: 0.35)) {
                    showAddCamera = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Camera")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.filmBackground)
                .padding(.horizontal, 32)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.filmAccent, Color.filmGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.filmAccent.opacity(0.35), radius: 12, x: 0, y: 5)
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
                    .fill(
                        LinearGradient(
                            colors: [Color.filmAccent.opacity(0.12), Color.filmGold.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.filmAccent.opacity(0.15), lineWidth: 0.5)
                    )
                Image(systemName: "camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(camera.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.filmText)
                HStack(spacing: 6) {
                    Text(camera.filmFormat.displayName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.filmAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.filmAccent.opacity(0.1))
                        )
                    Text(camera.cameraType.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmSecondary)
                    Text("·")
                        .foregroundColor(Color.filmTertiary)
                    Text("\(rollCount) rolls")
                        .font(.system(size: 12))
                        .foregroundColor(Color.filmSecondary)
                }
            }
            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .filmCard(cornerRadius: 18)
    }
}
