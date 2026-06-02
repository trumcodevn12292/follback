import SwiftUI
import SwiftData

@main
struct FilmVaultApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withTheme()
        }
        .modelContainer(for: [Roll.self, Frame.self, Camera.self])
    }
}
