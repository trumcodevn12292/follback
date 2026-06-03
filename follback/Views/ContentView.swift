import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab = 0
    @State private var tabAppeared = false

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    hasSeenOnboarding = true
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            TabView(selection: $selectedTab) {
                RollsView()
                    .tabItem {
                        Image(systemName: selectedTab == 0 ? "film.fill" : "film")
                        Text("Rolls")
                    }
                    .tag(0)

                CamerasView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "camera.fill" : "camera")
                        Text("Cameras")
                    }
                    .tag(1)

                SettingsView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                        Text("Settings")
                    }
                    .tag(2)
            }
            .tint(Color.filmAccent)
            .opacity(tabAppeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35)) {
                    tabAppeared = true
                }
            }
        }
    }
}
