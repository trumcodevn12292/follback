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

    /// Representative locale for each supported currency so grouping size,
    /// grouping separator and decimal separator follow that currency's own
    /// conventions (e.g. VND "1.500.000", EUR "1.500.000,00", INR "15,00,000",
    /// RUB "1 500 000,00").
    static func currencyLocale(for code: String? = nil) -> Locale {
        let target = code ?? currencyCode
        let map: [String: String] = [
            "USD": "en_US", "EUR": "de_DE", "GBP": "en_GB", "JPY": "ja_JP",
            "VND": "vi_VN", "CNY": "zh_Hans_CN", "KRW": "ko_KR", "INR": "hi_IN",
            "RUB": "ru_RU", "AUD": "en_AU", "CAD": "en_CA", "THB": "th_TH",
            "SGD": "en_SG"
        ]
        return Locale(identifier: map[target] ?? "en_US")
    }

    /// Number of fractional digits a currency uses by convention (0 for JPY,
    /// VND, KRW; 2 for USD, EUR, …).
    static func fractionDigits(for code: String? = nil) -> Int {
        let target = code ?? currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = target
        formatter.locale = Locale(identifier: "en_US")
        _ = formatter.string(from: 0)
        return formatter.maximumFractionDigits
    }

    private static func decimalFormatter(for code: String?) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = currencyLocale(for: code)
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits(for: code)
        return formatter
    }

    /// Formats an amount as currency using the currency's own locale so the
    /// grouping/decimal style and fraction digits match that currency.
    static func format(_ amount: Double, code: String? = nil) -> String {
        let target = code ?? currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currencyLocale(for: target)
        formatter.currencyCode = target
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits(for: target)
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Formats just the grouped number (no currency symbol), respecting the
    /// currency's grouping/decimal conventions.
    static func formatNumber(_ amount: Double, code: String? = nil) -> String {
        decimalFormatter(for: code).string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    /// Symbol (e.g. "$", "₫") for the given currency code, for use as a field prefix.
    static func symbol(for code: String? = nil) -> String {
        let target = code ?? currencyCode
        let locale = NSLocale(localeIdentifier: appLocale().identifier)
        return locale.displayName(forKey: .currencySymbol, value: target) ?? target
    }

    /// Live formatting for a price text field. Groups the integer part using the
    /// currency's own grouping rules while the user types, and keeps a single
    /// decimal mark (only when the currency uses fractional digits).
    static func groupedInput(_ raw: String, code: String? = nil) -> String {
        let loc = currencyLocale(for: code)
        let groupSep = loc.groupingSeparator ?? ","
        let decSep = loc.decimalSeparator ?? "."
        let maxFrac = fractionDigits(for: code)

        var intDigits = ""
        var fracDigits = ""
        var hasDec = false
        for ch in raw {
            if ch.isNumber {
                if hasDec {
                    if fracDigits.count < maxFrac { fracDigits.append(ch) }
                } else {
                    intDigits.append(ch)
                }
            } else if maxFrac > 0 && !hasDec && !intDigits.isEmpty {
                let s = String(ch)
                // A separator that isn't the grouping separator starts the decimals.
                if s != groupSep && (s == decSep || s == "." || s == ",") {
                    hasDec = true
                }
            }
        }
        while intDigits.count > 1 && intDigits.first == "0" { intDigits.removeFirst() }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = loc
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0

        let grouped: String
        if intDigits.isEmpty {
            grouped = hasDec ? "0" : ""
        } else {
            grouped = formatter.string(from: NSDecimalNumber(string: intDigits)) ?? intDigits
        }
        return hasDec ? grouped + decSep + fracDigits : grouped
    }

    /// Parses a user-typed amount, stripping the currency's grouping separators
    /// and normalizing its decimal mark. Returns nil for empty/non-positive.
    static func parseAmount(_ text: String, code: String? = nil) -> Double? {
        let loc = currencyLocale(for: code)
        let groupSep = loc.groupingSeparator ?? ","
        let decSep = loc.decimalSeparator ?? "."
        var s = text
        for sep in [groupSep, " ", "\u{00a0}", "\u{202f}"] {
            s = s.replacingOccurrences(of: sep, with: "")
        }
        s = s.replacingOccurrences(of: decSep, with: ".")

        var cleaned = ""
        var dotUsed = false
        for ch in s {
            if ch.isNumber {
                cleaned.append(ch)
            } else if ch == "." && !dotUsed {
                cleaned.append(".")
                dotUsed = true
            }
        }
        guard !cleaned.isEmpty, let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    /// Renders a stored amount as grouped input text (no currency symbol) using
    /// the currency's conventions, dropping trailing zeros. Used to prefill
    /// edit fields.
    static func editableText(_ value: Double, code: String? = nil) -> String {
        decimalFormatter(for: code).string(from: NSNumber(value: value)) ?? "\(value)"
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
