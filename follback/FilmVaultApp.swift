import SwiftUI
import SwiftData
import Kingfisher
import WidgetKit
import UserNotifications

@main
struct FilmVaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
        cache.memoryStorage.config.countLimit = 50
        cache.diskStorage.config.sizeLimit = 300 * 1024 * 1024

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { _ in
            ImageCache.default.clearMemoryCache()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .withTheme()
                .onAppear {
                    migrateDataIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Roll.self, Frame.self, Camera.self, CustomFilmModel.self,
                migrationPlan: FilmVaultMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    private func migrateDataIfNeeded() {
        let context = sharedModelContainer.mainContext
        CustomFilmModel.migrateFromUserDefaults(modelContext: context)
        KeychainService.migrateFromUserDefaults(
            userDefaultsKey: "google_drive_access_token",
            keychainKey: "google_drive_access_token"
        )
        KeychainService.migrateFromUserDefaults(
            userDefaultsKey: "google_drive_refresh_token",
            keychainKey: "google_drive_refresh_token"
        )
    }
}

// MARK: - App Delegate for Quick Actions

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            ReminderManager.shared.refreshAuthorizationStatus()
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Show reminders as banners even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
    }

    private func handleShortcutItem(_ item: UIApplicationShortcutItem) {
        if item.type == "com.williamcachamwri.FilmVault.newRoll" {
            NotificationCenter.default.post(name: .quickActionNewRoll, object: nil)
        } else if item.type == "com.williamcachamwri.FilmVault.settings" {
            NotificationCenter.default.post(name: .quickActionSettings, object: nil)
        } else if item.type.hasPrefix("com.williamcachamwri.FilmVault.recentRoll") {
            let userInfo: [AnyHashable: Any]?
            if let rollID = item.userInfo?["rollID"] as? String {
                userInfo = ["rollID": rollID]
            } else {
                userInfo = nil
            }
            NotificationCenter.default.post(name: .quickActionRecentRoll, object: nil, userInfo: userInfo)
        }
    }
}

// MARK: - Shake Detection

extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
