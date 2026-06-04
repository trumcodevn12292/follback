import Foundation
import Combine
import SwiftUI
import ObjectiveC
import WidgetKit

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
    static let appGroup = "group.com.williamcachamwri.FilmVault"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            Bundle.setAppLanguage(language.rawValue)
            Self.shareWithWidget(language.rawValue)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        let resolved = saved.flatMap(AppLanguage.init(rawValue:))
            ?? LocalizationManager.systemDefault()
        self.language = resolved
        Bundle.setAppLanguage(resolved.rawValue)
        Self.shareWithWidget(resolved.rawValue)
    }

    /// Mirror the chosen language into the shared App Group so the widget
    /// extension (a separate process/bundle) can localize itself too.
    private static func shareWithWidget(_ code: String) {
        UserDefaults(suiteName: appGroup)?.set(code, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
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

/// Locale matching the in-app selected language, so dates/numbers format in the
/// chosen language instead of the device locale. Reads UserDefaults directly so
/// it is safe to call from any context.
func appLocale() -> Locale {
    let code = UserDefaults.standard.string(forKey: LocalizationManager.key) ?? "en"
    return Locale(identifier: code)
}

// MARK: - Currency / money formatting

/// Lightweight currency helper for the roll cost-tracking feature. The chosen
/// currency code is stored app-wide (via `@AppStorage("currencyCode")`) so all
/// amounts are shown in a single currency and can be summed for totals.
enum Money {
    static let currencyKey = "currencyCode"

    /// A reasonable spread of currencies including the app's localized markets.
    static let commonCodes = [
        "USD", "EUR", "GBP", "JPY", "VND", "CNY",
        "KRW", "INR", "RUB", "AUD", "CAD", "THB", "SGD"
    ]

    static var defaultCode: String {
        if #available(iOS 16.0, *) {
            return Locale.current.currency?.identifier ?? "USD"
        }
        return Locale.current.currencyCode ?? "USD"
    }

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: currencyKey) ?? defaultCode
    }

    /// Formats an amount as currency using the app's selected language locale so
    /// grouping/decimal separators match the UI language. Whole numbers drop the
    /// fractional part for a cleaner look.
    static func format(_ amount: Double, code: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = appLocale()
        formatter.currencyCode = code ?? currencyCode
        formatter.maximumFractionDigits = amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Symbol (e.g. "$", "₫") for the given currency code, for use as a field prefix.
    static func symbol(for code: String? = nil) -> String {
        let target = code ?? currencyCode
        let locale = NSLocale(localeIdentifier: appLocale().identifier)
        return locale.displayName(forKey: .currencySymbol, value: target) ?? target
    }
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
