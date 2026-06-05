import SwiftUI
import Photos
import CoreLocation
import Combine

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @StateObject private var locationManager = OnboardingLocationManager()

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("camera.aperture", "FilmVault", "Your analog film journal"),
        ("film.stack", "Track Every Roll", "Film stocks, cameras, and locations"),
        ("photo.stack", "Relive the Journey", "Photos, stats, and contact sheets")
    ]

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 40) {
                    Image(systemName: pages[currentPage].icon)
                        .font(.system(size: 56, weight: .thin))
                        .foregroundColor(Color.filmAccent)
                        .frame(height: 64)
                        .id(currentPage)
                        .transition(.opacity)

                    VStack(spacing: 12) {
                        Text(L(pages[currentPage].title))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .id("title-\(currentPage)")
                            .transition(.opacity)

                        Text(L(pages[currentPage].subtitle))
                            .font(.system(size: 16))
                            .foregroundColor(Color.filmSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                            .id("sub-\(currentPage)")
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                Spacer()
                Spacer()

                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Circle()
                                .fill(currentPage == i ? Color.filmAccent : Color.filmBorder.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(currentPage == i ? 1.2 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if currentPage < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                            // Request permissions on page transitions
                            if currentPage == 1 {
                                requestPhotoAccess()
                            } else if currentPage == 2 {
                                requestLocationAccess()
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? L("Continue") : L("Get Started"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.filmBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(Color.filmAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    if currentPage < pages.count - 1 {
                        Button {
                            onComplete()
                        } label: {
                            Text(L("Skip"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 48)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -30 && currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    } else if value.translation.width > 30 && currentPage > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage -= 1 }
                    }
                }
        )
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text(permissionAlertMessage)
        }
    }

    private func requestPhotoAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .denied || status == .restricted {
            permissionAlertMessage = "Photo access is required to attach photos to your rolls. You can enable it in Settings."
            showPermissionAlert = true
            return
        }
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .denied || newStatus == .restricted {
                    DispatchQueue.main.async {
                        permissionAlertMessage = "Photo access is required to attach photos to your rolls. You can enable it in Settings."
                        showPermissionAlert = true
                    }
                }
            }
        }
    }

    private func requestLocationAccess() {
        let status = locationManager.authorizationStatus
        if status == .denied || status == .restricted {
            permissionAlertMessage = "Location access is optional but helps tag your photos with where they were taken. You can enable it in Settings."
            showPermissionAlert = true
            return
        }
        if status == .notDetermined {
            locationManager.requestPermission()
        }
    }
}

private class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
