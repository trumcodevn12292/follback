import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
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
            Group {
                switch selectedTab {
                case 0: RollsView()
                case 1: CamerasView()
                case 2: SearchView()
                case 3: SettingsView()
                default: RollsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            floatingTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var floatingTabBar: some View {
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
                        .fill(Color.filmSurface.opacity(0.85))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, max(8, bottomSafeArea))
    }

    private func tabItem(index: Int) -> some View {
        let icons = ["film", "camera", "magnifyingglass", "gearshape"]
        let labels = ["Rolls", "Cameras", "Find", "Settings"]
        let isSelected = selectedTab == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? iconFilled(icons[index]) : icons[index])
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
                    .frame(height: 22)

                Text(labels[index])
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color.filmAccent : Color.filmTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(Color.filmAccent.opacity(0.1))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func iconFilled(_ name: String) -> String {
        switch name {
        case "camera": return "camera.fill"
        case "gearshape": return "gearshape.fill"
        case "magnifyingglass": return "magnifyingglass"
        default: return name
        }
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.bottom ?? 0
    }
}
