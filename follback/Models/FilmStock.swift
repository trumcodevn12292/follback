import SwiftUI
import Combine

struct FilmStock: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let brand: String
    let iso: Int?
    let filmType: String
    let process: String?
    let frameCount: Int
    let frameFormats: [String]
    let inProduction: Bool
    let coverUrl: String?
    let brandLogoUrl: String?
    let filmDescription: String?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, iso, filmType, process, frameCount, frameFormats
        case inProduction, coverUrl, brandLogoUrl
        case filmDescription = "description"
    }

    var displayName: String { "\(brand) \(name)" }
    var shortName: String { name }

    var type: FilmStockType {
        switch filmType {
        case "COLOR_NEGATIVE": return .colorNegative
        case "COLOR_POSITIVE", "COLOR_REVERSAL": return .colorPositive
        case "BW_NEGATIVE", "BW_REVERSAL": return .blackAndWhite
        case "CINEMA": return .cinema
        case "INSTANT": return .instant
        default: return .specialty
        }
    }

    var isoValue: Int { iso ?? 400 }

    var color: Color {
        switch type {
        case .colorNegative: return Color(hex: "#F0DFC4")
        case .colorPositive: return Color(hex: "#3A7BD5")
        case .blackAndWhite: return Color(hex: "#999999")
        case .cinema: return Color(hex: "#2DD4BF")
        case .instant: return Color(hex: "#F472B6")
        case .specialty: return Color(hex: "#A855F7")
        }
    }

    var accentColor: Color {
        switch type {
        case .colorNegative: return Color(hex: "#D4A574")
        case .colorPositive: return Color(hex: "#2563EB")
        case .blackAndWhite: return Color(hex: "#555555")
        case .cinema: return Color(hex: "#14B8A6")
        case .instant: return Color(hex: "#EC4899")
        case .specialty: return Color(hex: "#9333EA")
        }
    }

    var fullCoverUrl: String? {
        guard let url = coverUrl, !url.isEmpty else { return nil }
        return "https://api.getfilmer.com\(url)"
    }

    var githubCoverUrl: String? {
        guard coverUrl != nil, !coverUrl!.isEmpty else { return nil }
        let fileName = "\(brand)_\(name)"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "'", with: "")
        return "https://raw.githubusercontent.com/williamcachamwri/film_covers/main/\(fileName).png"
    }

    var fullBrandLogoUrl: String? {
        guard let url = brandLogoUrl, !url.isEmpty else { return nil }
        return "https://api.getfilmer.com\(url)"
    }

    enum FilmStockType: String {
        case colorNegative = "Color Negative"
        case colorPositive = "Color Positive"
        case blackAndWhite = "Black & White"
        case cinema = "Cinema"
        case instant = "Instant"
        case specialty = "Specialty"
    }

    // MARK: - Data Loading

    private static var _allStocks: [FilmStock]?

    static var allStocks: [FilmStock] {
        if let cached = _allStocks { return cached }
        guard let url = Bundle.main.url(forResource: "film_models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let stocks = try? JSONDecoder().decode([FilmStock].self, from: data) else {
            return []
        }
        _allStocks = stocks
        return stocks
    }

    static let popularBrands = [
        "Kodak", "Fujifilm", "Ilford", "CineStill", "Lomography", "Agfa",
        "Foma", "Rollei", "Kentmere", "Harman", "ORWO", "Ferrania"
    ]

    static var groupedByBrand: [(brand: String, stocks: [FilmStock])] {
        let grouped = Dictionary(grouping: allStocks) { $0.brand }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (brand: $0.key, stocks: $0.value) }
    }

    static var groupedByBrandPopularFirst: [(brand: String, stocks: [FilmStock])] {
        let grouped = Dictionary(grouping: allStocks) { $0.brand }
        let popular = popularBrands.compactMap { brand -> (brand: String, stocks: [FilmStock])? in
            guard let stocks = grouped[brand], !stocks.isEmpty else { return nil }
            return (brand: brand, stocks: stocks)
        }
        let others = grouped
            .filter { !popularBrands.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { (brand: $0.key, stocks: $0.value) }
        return popular + others
    }
}

// MARK: - Custom Film

struct CustomFilm: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var iso: Int
    var filmType: String  // "COLOR_NEGATIVE", "BW_NEGATIVE", "COLOR_POSITIVE"
    var coverImageData: Data?

    var displayName: String { name }

    var type: FilmStock.FilmStockType {
        switch filmType {
        case "COLOR_NEGATIVE": return .colorNegative
        case "BW_NEGATIVE": return .blackAndWhite
        case "COLOR_POSITIVE": return .colorPositive
        default: return .colorNegative
        }
    }

    var typeDisplayName: String {
        switch filmType {
        case "COLOR_NEGATIVE": return "Color Negative"
        case "BW_NEGATIVE": return "Black & White"
        case "COLOR_POSITIVE": return "Color Positive"
        default: return "Color Negative"
        }
    }

    static let filmTypes = ["COLOR_NEGATIVE", "BW_NEGATIVE", "COLOR_POSITIVE"]
    static let filmTypeNames = ["Color Negative", "Black & White", "Color Positive"]
}

class CustomFilmStore: ObservableObject {
    static let shared = CustomFilmStore()
    @Published var films: [CustomFilm] = []

    private let key = "customFilms"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomFilm].self, from: data) else { return }
        films = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(films) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ film: CustomFilm) {
        films.append(film)
        save()
    }

    func remove(_ film: CustomFilm) {
        films.removeAll { $0.id == film.id }
        save()
    }
}
