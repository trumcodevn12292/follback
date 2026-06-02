import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab = 0

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.4)) {
                    hasSeenOnboarding = true
                }
            }
        } else {
            TabView(selection: $selectedTab) {
                RollsView()
                    .tabItem {
                        Image(systemName: "film")
                        Text("Rolls")
                    }
                    .tag(0)

                CamerasView()
                    .tabItem {
                        Image(systemName: selectedTab == 1 ? "camera.fill" : "camera")
                        Text("Cameras")
                    }
                    .tag(1)

                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Find")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Image(systemName: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .tint(Color.filmAccent)
        }
    }
}
