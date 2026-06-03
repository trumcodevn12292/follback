import SwiftUI
import Combine

// MARK: - Accent color options (Settings → Appearance)

struct AccentOption: Identifiable, Equatable {
    let id: String        // hex, also the persisted value
    let name: String
    var hex: String { id }
    var color: Color { Color(hex: id) }

    static let all: [AccentOption] = [
        AccentOption(id: "#E8A832", name: "Amber"),
        AccentOption(id: "#FB923C", name: "Orange"),
        AccentOption(id: "#F87171", name: "Crimson"),
        AccentOption(id: "#FB7185", name: "Rose"),
        AccentOption(id: "#A78BFA", name: "Violet"),
        AccentOption(id: "#60A5FA", name: "Sky"),
        AccentOption(id: "#2DD4BF", name: "Teal"),
        AccentOption(id: "#34D399", name: "Emerald")
    ]
}

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    static let accentKey = "accentColorHex"

    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "darkMode") }
    }

    /// Persisted accent hex. Writing it updates `Color.filmAccent` everywhere.
    @Published var accentHex: String {
        didSet { UserDefaults.standard.set(accentHex, forKey: ThemeManager.accentKey) }
    }

    init() {
        self.isDarkMode = UserDefaults.standard.object(forKey: "darkMode") as? Bool ?? true
        self.accentHex = UserDefaults.standard.string(forKey: ThemeManager.accentKey) ?? Color.defaultAccentHex
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

/// Root wrapper that re-renders the whole tree when the theme/accent changes,
/// guaranteeing the new accent applies everywhere (even in views that read
/// `Color.filmAccent` directly).
struct ThemedRoot<Content: View>: View {
    @ObservedObject private var manager = ThemeManager.shared
    let content: Content

    var body: some View {
        content
            .environmentObject(manager)
            .environment(\.theme, manager)
            .tint(Color.filmAccent)
            .preferredColorScheme(manager.isDarkMode ? .dark : .light)
            .id(manager.accentHex + (manager.isDarkMode ? "-d" : "-l"))
    }
}

extension View {
    func withTheme() -> some View {
        ThemedRoot(content: self)
    }
}
