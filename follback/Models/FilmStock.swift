import SwiftUI

struct FilmStock: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let brand: String
    let iso: Int
    let type: FilmStockType
    let color: Color
    let accentColor: Color

    var displayName: String { "\(brand) \(name)" }
    var shortName: String { name }

    enum FilmStockType: String {
        case colorNegative = "Color Negative"
        case colorPositive = "Color Positive"
        case blackAndWhite = "Black & White"
        case cinema = "Cinema"
        case instant = "Instant"
        case specialty = "Specialty"
    }

    static let allStocks: [FilmStock] = kodak + fujifilm + ilford + cinestill + lomography + foma + rollei + agfa + kentmere + bergger + washi + dubblefilm + harman + revolog + yodica

    // MARK: - Kodak
    static let kodak: [FilmStock] = [
        FilmStock(name: "Portra 160", brand: "Kodak", iso: 160, type: .colorNegative, color: Color(hex: "#E8D5B7"), accentColor: Color(hex: "#C4956A")),
        FilmStock(name: "Portra 400", brand: "Kodak", iso: 400, type: .colorNegative, color: Color(hex: "#F0DFC4"), accentColor: Color(hex: "#D4A574")),
        FilmStock(name: "Portra 800", brand: "Kodak", iso: 800, type: .colorNegative, color: Color(hex: "#F5E6CC"), accentColor: Color(hex: "#E0B88A")),
        FilmStock(name: "Ektar 100", brand: "Kodak", iso: 100, type: .colorNegative, color: Color(hex: "#E85D3A"), accentColor: Color(hex: "#C94428")),
        FilmStock(name: "Gold 200", brand: "Kodak", iso: 200, type: .colorNegative, color: Color(hex: "#FFD700"), accentColor: Color(hex: "#DAA520")),
        FilmStock(name: "ColorPlus 200", brand: "Kodak", iso: 200, type: .colorNegative, color: Color(hex: "#FFE066"), accentColor: Color(hex: "#E6C200")),
        FilmStock(name: "UltraMax 400", brand: "Kodak", iso: 400, type: .colorNegative, color: Color(hex: "#FF4444"), accentColor: Color(hex: "#CC2222")),
        FilmStock(name: "Tri-X 400", brand: "Kodak", iso: 400, type: .blackAndWhite, color: Color(hex: "#888888"), accentColor: Color(hex: "#555555")),
        FilmStock(name: "T-Max 100", brand: "Kodak", iso: 100, type: .blackAndWhite, color: Color(hex: "#AAAAAA"), accentColor: Color(hex: "#666666")),
        FilmStock(name: "T-Max 400", brand: "Kodak", iso: 400, type: .blackAndWhite, color: Color(hex: "#999999"), accentColor: Color(hex: "#555555")),
        FilmStock(name: "T-Max P3200", brand: "Kodak", iso: 3200, type: .blackAndWhite, color: Color(hex: "#777777"), accentColor: Color(hex: "#444444")),
        FilmStock(name: "Ektachrome E100", brand: "Kodak", iso: 100, type: .colorPositive, color: Color(hex: "#3A7BD5"), accentColor: Color(hex: "#2563EB")),
        FilmStock(name: "Vision3 50D", brand: "Kodak", iso: 50, type: .cinema, color: Color(hex: "#2DD4BF"), accentColor: Color(hex: "#14B8A6")),
        FilmStock(name: "Vision3 250D", brand: "Kodak", iso: 250, type: .cinema, color: Color(hex: "#34D399"), accentColor: Color(hex: "#10B981")),
        FilmStock(name: "Vision3 500T", brand: "Kodak", iso: 500, type: .cinema, color: Color(hex: "#818CF8"), accentColor: Color(hex: "#6366F1")),
    ]

    // MARK: - Fujifilm
    static let fujifilm: [FilmStock] = [
        FilmStock(name: "Superia X-TRA 400", brand: "Fujifilm", iso: 400, type: .colorNegative, color: Color(hex: "#22C55E"), accentColor: Color(hex: "#16A34A")),
        FilmStock(name: "Superia 200", brand: "Fujifilm", iso: 200, type: .colorNegative, color: Color(hex: "#4ADE80"), accentColor: Color(hex: "#22C55E")),
        FilmStock(name: "C200", brand: "Fujifilm", iso: 200, type: .colorNegative, color: Color(hex: "#86EFAC"), accentColor: Color(hex: "#4ADE80")),
        FilmStock(name: "Pro 400H", brand: "Fujifilm", iso: 400, type: .colorNegative, color: Color(hex: "#BBF7D0"), accentColor: Color(hex: "#86EFAC")),
        FilmStock(name: "Velvia 50", brand: "Fujifilm", iso: 50, type: .colorPositive, color: Color(hex: "#DC2626"), accentColor: Color(hex: "#B91C1C")),
        FilmStock(name: "Velvia 100", brand: "Fujifilm", iso: 100, type: .colorPositive, color: Color(hex: "#EF4444"), accentColor: Color(hex: "#DC2626")),
        FilmStock(name: "Provia 100F", brand: "Fujifilm", iso: 100, type: .colorPositive, color: Color(hex: "#3B82F6"), accentColor: Color(hex: "#2563EB")),
        FilmStock(name: "Acros II 100", brand: "Fujifilm", iso: 100, type: .blackAndWhite, color: Color(hex: "#A3A3A3"), accentColor: Color(hex: "#737373")),
        FilmStock(name: "Neopan 400", brand: "Fujifilm", iso: 400, type: .blackAndWhite, color: Color(hex: "#8B8B8B"), accentColor: Color(hex: "#5C5C5C")),
    ]

    // MARK: - Ilford
    static let ilford: [FilmStock] = [
        FilmStock(name: "HP5 Plus 400", brand: "Ilford", iso: 400, type: .blackAndWhite, color: Color(hex: "#404040"), accentColor: Color(hex: "#262626")),
        FilmStock(name: "Delta 100", brand: "Ilford", iso: 100, type: .blackAndWhite, color: Color(hex: "#D4D4D4"), accentColor: Color(hex: "#A3A3A3")),
        FilmStock(name: "Delta 400", brand: "Ilford", iso: 400, type: .blackAndWhite, color: Color(hex: "#B0B0B0"), accentColor: Color(hex: "#808080")),
        FilmStock(name: "Delta 3200", brand: "Ilford", iso: 3200, type: .blackAndWhite, color: Color(hex: "#707070"), accentColor: Color(hex: "#404040")),
        FilmStock(name: "FP4 Plus 125", brand: "Ilford", iso: 125, type: .blackAndWhite, color: Color(hex: "#C0C0C0"), accentColor: Color(hex: "#909090")),
        FilmStock(name: "Pan F Plus 50", brand: "Ilford", iso: 50, type: .blackAndWhite, color: Color(hex: "#E0E0E0"), accentColor: Color(hex: "#B0B0B0")),
        FilmStock(name: "XP2 Super 400", brand: "Ilford", iso: 400, type: .blackAndWhite, color: Color(hex: "#9CA3AF"), accentColor: Color(hex: "#6B7280")),
        FilmStock(name: "SFX 200", brand: "Ilford", iso: 200, type: .blackAndWhite, color: Color(hex: "#7C3AED"), accentColor: Color(hex: "#6D28D9")),
    ]

    // MARK: - CineStill
    static let cinestill: [FilmStock] = [
        FilmStock(name: "800T", brand: "CineStill", iso: 800, type: .cinema, color: Color(hex: "#F59E0B"), accentColor: Color(hex: "#D97706")),
        FilmStock(name: "50D", brand: "CineStill", iso: 50, type: .cinema, color: Color(hex: "#06B6D4"), accentColor: Color(hex: "#0891B2")),
        FilmStock(name: "400D", brand: "CineStill", iso: 400, type: .cinema, color: Color(hex: "#8B5CF6"), accentColor: Color(hex: "#7C3AED")),
    ]

    // MARK: - Lomography
    static let lomography: [FilmStock] = [
        FilmStock(name: "Color Negative 100", brand: "Lomography", iso: 100, type: .colorNegative, color: Color(hex: "#A855F7"), accentColor: Color(hex: "#9333EA")),
        FilmStock(name: "Color Negative 400", brand: "Lomography", iso: 400, type: .colorNegative, color: Color(hex: "#C084FC"), accentColor: Color(hex: "#A855F7")),
        FilmStock(name: "Color Negative 800", brand: "Lomography", iso: 800, type: .colorNegative, color: Color(hex: "#D8B4FE"), accentColor: Color(hex: "#C084FC")),
        FilmStock(name: "Lady Grey 400", brand: "Lomography", iso: 400, type: .blackAndWhite, color: Color(hex: "#D1D5DB"), accentColor: Color(hex: "#9CA3AF")),
        FilmStock(name: "Berlin Kino 400", brand: "Lomography", iso: 400, type: .blackAndWhite, color: Color(hex: "#78716C"), accentColor: Color(hex: "#57534E")),
        FilmStock(name: "LomoChrome Purple", brand: "Lomography", iso: 400, type: .specialty, color: Color(hex: "#C026D3"), accentColor: Color(hex: "#A21CAF")),
        FilmStock(name: "LomoChrome Metropolis", brand: "Lomography", iso: 100, type: .specialty, color: Color(hex: "#64748B"), accentColor: Color(hex: "#475569")),
        FilmStock(name: "LomoChrome Turquoise", brand: "Lomography", iso: 400, type: .specialty, color: Color(hex: "#2DD4BF"), accentColor: Color(hex: "#14B8A6")),
        FilmStock(name: "Redscale XR 50-200", brand: "Lomography", iso: 100, type: .specialty, color: Color(hex: "#EF4444"), accentColor: Color(hex: "#DC2626")),
    ]

    // MARK: - Foma
    static let foma: [FilmStock] = [
        FilmStock(name: "Fomapan 100", brand: "Foma", iso: 100, type: .blackAndWhite, color: Color(hex: "#D6D3D1"), accentColor: Color(hex: "#A8A29E")),
        FilmStock(name: "Fomapan 200", brand: "Foma", iso: 200, type: .blackAndWhite, color: Color(hex: "#C4B5A5"), accentColor: Color(hex: "#A8A29E")),
        FilmStock(name: "Fomapan 400", brand: "Foma", iso: 400, type: .blackAndWhite, color: Color(hex: "#A89F96"), accentColor: Color(hex: "#8C8278")),
    ]

    // MARK: - Rollei
    static let rollei: [FilmStock] = [
        FilmStock(name: "RPX 25", brand: "Rollei", iso: 25, type: .blackAndWhite, color: Color(hex: "#E5E5E5"), accentColor: Color(hex: "#BDBDBD")),
        FilmStock(name: "RPX 100", brand: "Rollei", iso: 100, type: .blackAndWhite, color: Color(hex: "#CCCCCC"), accentColor: Color(hex: "#999999")),
        FilmStock(name: "RPX 400", brand: "Rollei", iso: 400, type: .blackAndWhite, color: Color(hex: "#999999"), accentColor: Color(hex: "#666666")),
        FilmStock(name: "Infrared 400", brand: "Rollei", iso: 400, type: .specialty, color: Color(hex: "#BE185D"), accentColor: Color(hex: "#9D174D")),
        FilmStock(name: "Retro 80S", brand: "Rollei", iso: 80, type: .blackAndWhite, color: Color(hex: "#B8B8B8"), accentColor: Color(hex: "#8A8A8A")),
    ]

    // MARK: - Agfa
    static let agfa: [FilmStock] = [
        FilmStock(name: "APX 100", brand: "Agfa", iso: 100, type: .blackAndWhite, color: Color(hex: "#CBD5E1"), accentColor: Color(hex: "#94A3B8")),
        FilmStock(name: "APX 400", brand: "Agfa", iso: 400, type: .blackAndWhite, color: Color(hex: "#94A3B8"), accentColor: Color(hex: "#64748B")),
    ]

    // MARK: - Kentmere
    static let kentmere: [FilmStock] = [
        FilmStock(name: "Pan 100", brand: "Kentmere", iso: 100, type: .blackAndWhite, color: Color(hex: "#D4D4D8"), accentColor: Color(hex: "#A1A1AA")),
        FilmStock(name: "Pan 400", brand: "Kentmere", iso: 400, type: .blackAndWhite, color: Color(hex: "#A1A1AA"), accentColor: Color(hex: "#71717A")),
    ]

    // MARK: - Bergger
    static let bergger: [FilmStock] = [
        FilmStock(name: "Pancro 400", brand: "Bergger", iso: 400, type: .blackAndWhite, color: Color(hex: "#C9B99A"), accentColor: Color(hex: "#A39171")),
    ]

    // MARK: - Washi
    static let washi: [FilmStock] = [
        FilmStock(name: "Film S 50", brand: "Washi", iso: 50, type: .specialty, color: Color(hex: "#FDE68A"), accentColor: Color(hex: "#FCD34D")),
        FilmStock(name: "Film Z 400", brand: "Washi", iso: 400, type: .specialty, color: Color(hex: "#7DD3FC"), accentColor: Color(hex: "#38BDF8")),
    ]

    // MARK: - Dubblefilm
    static let dubblefilm: [FilmStock] = [
        FilmStock(name: "Apollo 400", brand: "Dubblefilm", iso: 400, type: .specialty, color: Color(hex: "#FB923C"), accentColor: Color(hex: "#F97316")),
        FilmStock(name: "Moonstruck 400", brand: "Dubblefilm", iso: 400, type: .specialty, color: Color(hex: "#A78BFA"), accentColor: Color(hex: "#8B5CF6")),
        FilmStock(name: "Sunstroke 200", brand: "Dubblefilm", iso: 200, type: .specialty, color: Color(hex: "#FBBF24"), accentColor: Color(hex: "#F59E0B")),
    ]

    // MARK: - Harman
    static let harman: [FilmStock] = [
        FilmStock(name: "Phoenix 200", brand: "Harman", iso: 200, type: .colorNegative, color: Color(hex: "#F472B6"), accentColor: Color(hex: "#EC4899")),
    ]

    // MARK: - Revolog
    static let revolog: [FilmStock] = [
        FilmStock(name: "Streak 200", brand: "Revolog", iso: 200, type: .specialty, color: Color(hex: "#F43F5E"), accentColor: Color(hex: "#E11D48")),
        FilmStock(name: "Kolor 200", brand: "Revolog", iso: 200, type: .specialty, color: Color(hex: "#EC4899"), accentColor: Color(hex: "#DB2777")),
    ]

    // MARK: - Yodica
    static let yodica: [FilmStock] = [
        FilmStock(name: "Andromeda 400", brand: "Yodica", iso: 400, type: .specialty, color: Color(hex: "#6366F1"), accentColor: Color(hex: "#4F46E5")),
        FilmStock(name: "Pegasus 200", brand: "Yodica", iso: 200, type: .specialty, color: Color(hex: "#14B8A6"), accentColor: Color(hex: "#0D9488")),
    ]

    // MARK: - Grouped by brand
    static var groupedByBrand: [(brand: String, stocks: [FilmStock])] {
        let brands = ["Kodak", "Fujifilm", "Ilford", "CineStill", "Lomography", "Foma", "Rollei", "Agfa", "Kentmere", "Bergger", "Harman", "Washi", "Dubblefilm", "Revolog", "Yodica"]
        return brands.compactMap { brand in
            let stocks = allStocks.filter { $0.brand == brand }
            return stocks.isEmpty ? nil : (brand: brand, stocks: stocks)
        }
    }
}
