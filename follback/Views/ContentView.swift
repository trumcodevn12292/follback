import SwiftUI
import SwiftData
import Combine
import UIKit
import WidgetKit

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var selectedTab = 0
    @State private var tabAppeared = false
    @State private var showNewRoll = false
    @Environment(\.modelContext) private var modelContext
    @Query private var allRolls: [Roll]

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
            .scaleEffect(tabAppeared ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    tabAppeared = true
                }
                updateWidgetData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionNewRoll)) { _ in
                selectedTab = 0
                showNewRoll = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSettings)) { _ in
                selectedTab = 2
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionRecentRoll)) { _ in
                selectedTab = 0
            }
            .sheet(isPresented: $showNewRoll) {
                NavigationStack {
                    AddRollView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: selectedTab) { _, _ in
                updateWidgetData()
            }
            .onChange(of: allRolls.count) { _, _ in
                updateWidgetData()
            }
            .onChange(of: allRolls.map { "\($0.status)_\(($0.frames ?? []).filter { $0.photoAssetID != nil }.count)" }) { _, _ in
                updateWidgetData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .widgetDataDidChange)) { _ in
                updateWidgetData()
            }
        }
    }

    private func updateWidgetData() {
        let descriptor = FetchDescriptor<Roll>()
        guard let rolls = try? modelContext.fetch(descriptor) else { return }
        WidgetDataService.updateWidget(rolls: rolls)
        updateQuickActions(rolls: rolls)
    }

    private func updateQuickActions(rolls: [Roll]) {
        var shortcuts: [UIApplicationShortcutItem] = [
            UIApplicationShortcutItem(
                type: "com.williamcachamwri.FilmVault.newRoll",
                localizedTitle: "New Roll",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.williamcachamwri.FilmVault.settings",
                localizedTitle: "Settings",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "gearshape.fill")
            )
        ]

        if let recentRoll = rolls.sorted(by: { $0.startDate > $1.startDate }).first {
            let recentItem = UIApplicationShortcutItem(
                type: "com.williamcachamwri.FilmVault.recentRoll",
                localizedTitle: recentRoll.filmName,
                localizedSubtitle: "Recent roll",
                icon: UIApplicationShortcutIcon(systemImageName: "film")
            )
            shortcuts.insert(recentItem, at: 0)
        }

        UIApplication.shared.shortcutItems = shortcuts
    }
}

extension Notification.Name {
    static let quickActionNewRoll = Notification.Name("quickActionNewRoll")
    static let quickActionSettings = Notification.Name("quickActionSettings")
    static let quickActionRecentRoll = Notification.Name("quickActionRecentRoll")
    static let widgetDataDidChange = Notification.Name("widgetDataDidChange")
}
