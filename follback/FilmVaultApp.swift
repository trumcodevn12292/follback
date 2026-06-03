import SwiftUI
import SwiftData
import Kingfisher

@main
struct FilmVaultApp: App {

    init() {
        configureImageCache()
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

    private func configureImageCache() {
        let cache = ImageCache.default
        // Keep disk cache for 30 days (default is 7)
        cache.diskStorage.config.expiration = .days(30)
        // 500 MB disk limit (default is 150 MB)
        cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024
        // Keep memory cache generous
        cache.memoryStorage.config.totalCostLimit = 100 * 1024 * 1024
        cache.memoryStorage.config.countLimit = 200
    }
}
