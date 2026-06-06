import SwiftUI
import Combine
import WidgetKit

// MARK: - Appearance mode

enum AppearanceMode: String, CaseIterable {
    case dark   = "dark"
    case light  = "light"
    case system = "system"
}

extension AppearanceMode {
    var displayName: String {
        switch self {
        case .dark:   return "Dark"
        case .light:  return "Light"
        case .system: return "System"
        }
    }

    var iconName: String {
        switch self {
        case .dark:   return "moon.fill"
        case .light:  return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

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
    static let appearanceKey = "appearanceMode"

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: ThemeManager.appearanceKey)
            UserDefaults(suiteName: "group.com.williamcachamwri.FilmVault")?
                .set(appearanceMode.rawValue, forKey: ThemeManager.appearanceKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Persisted accent hex. Writing it updates `Color.filmAccent` everywhere.
    @Published var accentHex: String {
        didSet { UserDefaults.standard.set(accentHex, forKey: ThemeManager.accentKey) }
    }

    /// Computed helper so existing `manager.isDarkMode` callers still work.
    var isDarkMode: Bool {
        switch appearanceMode {
        case .dark:   return true
        case .light:  return false
        case .system: return UITraitCollection.current.userInterfaceStyle == .dark
        }
    }

    init() {
        // Migrate legacy "darkMode" key to new enum
        if let legacy = UserDefaults.standard.object(forKey: "darkMode") as? Bool {
            self.appearanceMode = legacy ? .dark : .light
            UserDefaults.standard.removeObject(forKey: "darkMode")
        } else if let saved = UserDefaults.standard.string(forKey: ThemeManager.appearanceKey),
                  let mode = AppearanceMode(rawValue: saved) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
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
    @ObservedObject private var l10n = LocalizationManager.shared
    let content: Content

    var body: some View {
        content
            .environmentObject(manager)
            .environmentObject(l10n)
            .environment(\.theme, manager)
            .environment(\.locale, l10n.isFollowingSystem ? Locale.current : Locale(identifier: l10n.language.rawValue))
            .environment(\.layoutDirection, l10n.language.isRTL ? .rightToLeft : .leftToRight)
            .tint(Color.filmAccent)
            .preferredColorScheme(
                manager.appearanceMode == .system ? nil :
                manager.appearanceMode == .dark   ? .dark : .light
            )
            .id(manager.accentHex + "-" + manager.appearanceMode.rawValue + "-" + l10n.language.rawValue + (l10n.isFollowingSystem ? "-sys" : ""))
    }
}

extension View {
    func withTheme() -> some View {
        ThemedRoot(content: self)
    }
}
