import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "darkMode") }
    }

    init() {
        self.isDarkMode = UserDefaults.standard.object(forKey: "darkMode") as? Bool ?? true
    }
}

struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func withTheme() -> some View {
        let manager = ThemeManager.shared
        return self
            .environmentObject(manager)
            .environment(\.theme, manager)
            .preferredColorScheme(manager.isDarkMode ? .dark : .light)
    }
}
