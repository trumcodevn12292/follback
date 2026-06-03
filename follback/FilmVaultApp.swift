import SwiftUI
import SwiftData
import Kingfisher
import WidgetKit

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
                .task {
                    await FilmerImageAuth.shared.ensureToken()
                }
        }
        .modelContainer(for: [Roll.self, Frame.self, Camera.self])
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

// MARK: - App Delegate for Quick Actions

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
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
        switch item.type {
        case "com.williamcachamwri.FilmVault.newRoll":
            NotificationCenter.default.post(name: .quickActionNewRoll, object: nil)
        case "com.williamcachamwri.FilmVault.settings":
            NotificationCenter.default.post(name: .quickActionSettings, object: nil)
        case "com.williamcachamwri.FilmVault.recentRoll":
            NotificationCenter.default.post(name: .quickActionRecentRoll, object: nil)
        default:
            break
        }
    }
}
