import SwiftUI

struct CameraModel: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let brand: String
    let cameraType: String
    let coverUrl: String
    let brandLogoUrl: String
    let description: String

    var displayName: String { "\(brand) \(name)" }

    var fullCoverUrl: String? {
        guard !coverUrl.isEmpty else { return nil }
        return "https://api.getfilmer.com\(coverUrl)"
    }

    var fullBrandLogoUrl: String? {
        guard !brandLogoUrl.isEmpty else { return nil }
        return "https://api.getfilmer.com\(brandLogoUrl)"
    }

    // MARK: - Data Loading

    private static var _allModels: [CameraModel]?

    static var allModels: [CameraModel] {
        if let cached = _allModels { return cached }
        guard let url = Bundle.main.url(forResource: "camera_models", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode([CameraModel].self, from: data) else {
            return []
        }
        _allModels = models
        return models
    }

    static var groupedByBrand: [(brand: String, models: [CameraModel])] {
        let grouped = Dictionary(grouping: allModels) { $0.brand }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (brand: $0.key, models: $0.value) }
    }

    static var popularBrands: [String] {
        ["Canon", "Nikon", "Leica", "Olympus", "Pentax", "Minolta",
         "Contax", "Hasselblad", "Mamiya", "Fujifilm", "Yashica", "Rollei"]
    }

    static var groupedByBrandPopularFirst: [(brand: String, models: [CameraModel])] {
        let grouped = Dictionary(grouping: allModels) { $0.brand }
        let popular = popularBrands.compactMap { brand -> (brand: String, models: [CameraModel])? in
            guard let models = grouped[brand], !models.isEmpty else { return nil }
            return (brand: brand, models: models)
        }
        let others = grouped
            .filter { !popularBrands.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { (brand: $0.key, models: $0.value) }
        return popular + others
    }
}
