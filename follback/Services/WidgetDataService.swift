import Foundation
import SwiftData
import WidgetKit

struct WidgetDataService {
    static func updateWidget(rolls: [Roll]) {
        guard let defaults = UserDefaults(suiteName: "group.com.williamcachamwri.FilmVault") else { return }

        let totalRolls = rolls.count
        let totalPhotos = rolls.reduce(0) { sum, roll in
            sum + (roll.frames ?? []).filter { $0.photoAssetID != nil }.count
        }

        let recentRolls = rolls
            .sorted { $0.startDate > $1.startDate }
            .prefix(6)
            .map { roll in
                WidgetRollData(
                    id: roll.id.uuidString,
                    filmName: roll.filmName,
                    photoCount: (roll.frames ?? []).filter { $0.photoAssetID != nil }.count,
                    capacity: roll.capacity,
                    status: roll.status
                )
            }

        let widgetData = WidgetSharedData(
            totalRolls: totalRolls,
            totalPhotos: totalPhotos,
            recentRolls: Array(recentRolls)
        )

        if let encoded = try? JSONEncoder().encode(widgetData) {
            defaults.set(encoded, forKey: "widgetData")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WidgetSharedData: Codable {
    let totalRolls: Int
    let totalPhotos: Int
    let recentRolls: [WidgetRollData]
}

struct WidgetRollData: Codable {
    let id: String
    let filmName: String
    let photoCount: Int
    let capacity: Int
    let status: String
}
