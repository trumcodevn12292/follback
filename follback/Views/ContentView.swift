import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab = 0
    @Namespace private var tabAnimation

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        hasSeenOnboarding = true
                    }
                }
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            tabContent

            glassTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            RollsView()
        } else if selectedTab == 1 {
            CamerasView()
        } else if selectedTab == 2 {
            SearchView()
        } else {
            SettingsView()
        }
    }

    private var glassTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                tabItem(index: index)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.filmBorder.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, max(8, bottomSafeArea))
    }

    private func tabItem(index: Int) -> some View {
        let items = [
            ("camera.roll", "Rolls"),
            ("camera", "Cameras"),
            ("magnifyingglass", "Find"),
            ("gearshape.fill", "Settings")
        ]
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedTab = index
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: items[index].0)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .frame(height: 24)

                Text(items[index].1)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.filmAccent.opacity(0.12))
                            .matchedGeometryEffect(id: "activeTab", in: tabAnimation)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.bottom ?? 0
    }
}
