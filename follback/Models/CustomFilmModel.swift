import Foundation
import SwiftData
import UIKit

@Model
final class CustomFilmModel {
    var id: String
    var name: String
    var brand: String = ""
    var iso: Int
    var filmType: String
    var format: String = "35mm"
    var coverImageData: Data?
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, brand: String = "", iso: Int = 400,
         filmType: String = "COLOR_NEGATIVE", format: String = "35mm", coverImageData: Data? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.iso = iso
        self.filmType = filmType
        self.format = format
        self.coverImageData = coverImageData
        self.createdAt = Date()
    }

    var displayName: String { name }

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

    static let migrationKey = "CustomFilmModel_migrated"

    static func migrateFromUserDefaults(modelContext: ModelContext) {
        let hasMigrated = UserDefaults.standard.bool(forKey: migrationKey)
        guard !hasMigrated else { return }
        let store = CustomFilmStore.shared
        for film in store.films {
            let model = CustomFilmModel(
                id: film.id,
                name: film.name,
                brand: film.brand,
                iso: film.iso,
                filmType: film.filmType,
                format: film.format,
                coverImageData: film.coverImageData
            )
            modelContext.insert(model)
        }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
