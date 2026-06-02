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

            floatingTabBar
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

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                tabItem(index: index)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.filmGlass.opacity(0.7))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.filmBorder.opacity(0.6), Color.filmBorder.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 10)
                .shadow(color: Color.filmAccent.opacity(0.05), radius: 30, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, max(8, bottomSafeArea))
    }

    private func tabItem(index: Int) -> some View {
        let items = [
            ("film", "Rolls"),
            ("camera", "Cameras"),
            ("magnifyingglass", "Find"),
            ("gearshape", "Settings")
        ]
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = index
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.filmAccent.opacity(0.2), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)
                            .matchedGeometryEffect(id: "tabGlow", in: tabAnimation)
                    }

                    Image(systemName: isSelected ? items[index].0 + ".fill" : items[index].0)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.filmAccent, Color.filmGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ))
                            : AnyShapeStyle(Color.filmTertiary)
                        )
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .frame(height: 24)
                }

                Text(items[index].1)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.filmAccent.opacity(0.08))
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
