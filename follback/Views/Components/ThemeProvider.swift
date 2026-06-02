import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("darkMode") var isDarkMode: Bool = true
}

struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeManager()
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func withTheme() -> some View {
        let manager = ThemeManager()
        return self
            .environmentObject(manager)
            .environment(\.theme, manager)
            .preferredColorScheme(manager.isDarkMode ? .dark : .light)
    }
}
