import SwiftUI
import SwiftData
import Combine
import UIKit
import WidgetKit

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @SceneStorage("selectedTab") private var selectedTab = 0
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

                LabsView()
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "flask.fill" : "flask")
                        Text("Labs")
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
            .opacity(tabAppeared ? 1 : 0)
            .scaleEffect(tabAppeared ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    tabAppeared = true
                }
                updateWidgetData()
                consumePendingIntent()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                updateWidgetData()
                consumePendingIntent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionNewRoll)) { _ in
                selectedTab = 0
                showNewRoll = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSettings)) { _ in
                selectedTab = 3
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionRecentRoll)) { notification in
                selectedTab = 0
                if let rollID = notification.userInfo?["rollID"] as? String,
                   UUID(uuidString: rollID) != nil {
                    WidgetDeepLink.shared.pendingRollID = rollID
                }
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
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onChange(of: allRolls.map { "\($0.status)_\(($0.frames ?? []).filter { $0.photoAssetID != nil }.count)" }) { _, _ in
                updateWidgetData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .widgetDataDidChange)) { _ in
                updateWidgetData()
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "filmvault", url.host == "roll" else { return }
        let idString = url.lastPathComponent
        guard !idString.isEmpty, UUID(uuidString: idString) != nil else { return }
        selectedTab = 0
        WidgetDeepLink.shared.pendingRollID = idString
    }

    private func updateWidgetData() {
        let descriptor = FetchDescriptor<Roll>()
        guard let rolls = try? modelContext.fetch(descriptor) else { return }
        WidgetDataService.updateWidget(rolls: rolls)
        updateQuickActions(rolls: rolls)
        ReminderManager.shared.reschedule(rolls: rolls)
        LiveActivityManager.shared.sync(rolls: rolls)
    }

    /// Handle actions queued by App Intents / Siri while the app was not active.
    private func consumePendingIntent() {
        let defaults = UserDefaults(suiteName: "group.com.williamcachamwri.FilmVault")
        guard let action = defaults?.string(forKey: "pendingIntentAction") else { return }
        let rollID = defaults?.string(forKey: "pendingIntentRollID")
        defaults?.removeObject(forKey: "pendingIntentAction")
        defaults?.removeObject(forKey: "pendingIntentRollID")

        switch action {
        case "openRoll":
            if let rollID, UUID(uuidString: rollID) != nil {
                selectedTab = 0
                WidgetDeepLink.shared.pendingRollID = rollID
            }
        case "newRoll":
            selectedTab = 0
            showNewRoll = true
        case "startTracking":
            updateWidgetData()
        default:
            break
        }
        // Always re-sync widget data and Live Activity after consuming any intent
        updateWidgetData()
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

        let recentRolls = rolls
            .sorted { $0.startDate > $1.startDate }
            .prefix(3)

        for (index, roll) in recentRolls.enumerated() {
            let subtitle: String
            if let camera = roll.camera {
                subtitle = "\(camera.brand) \(camera.name)"
            } else {
                subtitle = "\(roll.filledFrames)/\(roll.capacity)"
            }
            let item = UIApplicationShortcutItem(
                type: "com.williamcachamwri.FilmVault.recentRoll.\(index)",
                localizedTitle: roll.filmName.isEmpty ? "Untitled" : roll.filmName,
                localizedSubtitle: subtitle,
                icon: UIApplicationShortcutIcon(systemImageName: "film"),
                userInfo: ["rollID": roll.id.uuidString as NSString]
            )
            shortcuts.insert(item, at: 0)
        }

        UIApplication.shared.shortcutItems = shortcuts
    }
}

@MainActor
final class WidgetDeepLink: ObservableObject {
    static let shared = WidgetDeepLink()
    /// Roll UUID string requested from a widget tap; consumed by RollsView.
    @Published var pendingRollID: String?
}

extension Notification.Name {
    static let quickActionNewRoll = Notification.Name("quickActionNewRoll")
    static let quickActionSettings = Notification.Name("quickActionSettings")
    static let quickActionRecentRoll = Notification.Name("quickActionRecentRoll")
    static let widgetDataDidChange = Notification.Name("widgetDataDidChange")
}
