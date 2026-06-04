import Foundation
import Combine
import SwiftUI
import ObjectiveC

// MARK: - Supported languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case russian = "ru"
    case spanish = "es"
    case arabic = "ar"
    case hindi = "hi"

    var id: String { rawValue }

    /// Name shown in the picker, in the language itself.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .russian: return "Русский"
        case .spanish: return "Español"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .vietnamese: return "🇻🇳"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .russian: return "🇷🇺"
        case .spanish: return "🇪🇸"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        }
    }

    var isRTL: Bool { self == .arabic }
}

// MARK: - Manager

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    static let key = "appLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            Bundle.setAppLanguage(language.rawValue)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        let resolved = saved.flatMap(AppLanguage.init(rawValue:))
            ?? LocalizationManager.systemDefault()
        self.language = resolved
        Bundle.setAppLanguage(resolved.rawValue)
    }

    private static func systemDefault() -> AppLanguage {
        for code in Locale.preferredLanguages {
            let lower = code.lowercased()
            if lower.hasPrefix("vi") { return .vietnamese }
            if lower.hasPrefix("zh") { return .chinese }
            if lower.hasPrefix("ja") { return .japanese }
            if lower.hasPrefix("ru") { return .russian }
            if lower.hasPrefix("es") { return .spanish }
            if lower.hasPrefix("ar") { return .arabic }
            if lower.hasPrefix("hi") { return .hindi }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }
}

// MARK: - Localized string helper

/// Look up a localized string using the in-app selected language bundle.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, arguments: args)
}

// MARK: - Runtime language switching (Bundle swizzling)

private var bundleAssocKey: UInt8 = 0

/// Bundle subclass whose `localizedString` reads from the selected .lproj.
private final class AppLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let langBundle = objc_getAssociatedObject(self, &bundleAssocKey) as? Bundle {
            return langBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Swap Bundle.main's class so all NSLocalizedString / SwiftUI LocalizedStringKey
    /// lookups resolve against the chosen language without restarting the app.
    static func setAppLanguage(_ language: String) {
        if !(Bundle.main is AppLanguageBundle) {
            object_setClass(Bundle.main, AppLanguageBundle.self)
        }
        let langBundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        objc_setAssociatedObject(Bundle.main, &bundleAssocKey, langBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
