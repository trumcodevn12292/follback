import SwiftUI
import Combine

/// Central theme provider that ensures consistent dark/light mode across the app.
/// Use via @Environment(\.theme) to react to theme changes.
class ThemeProvider: ObservableObject {
    @AppStorage("darkMode") var isDarkMode: Bool = true {
        didSet {
            objectWillChange.send()
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeProvider()
}

extension EnvironmentValues {
    var theme: ThemeProvider {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct ThemeModifier: ViewModifier {
    @StateObject private var theme = ThemeProvider()

    func body(content: Content) -> some View {
        content
            .environment(\.theme, theme)
            .preferredColorScheme(theme.isDarkMode ? .dark : .light)
    }
}

extension View {
    func withTheme() -> some View {
        modifier(ThemeModifier())
    }
}
