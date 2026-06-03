import SwiftUI
import SwiftData
import Kingfisher

@main
struct FilmVaultApp: App {
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
    }
}
