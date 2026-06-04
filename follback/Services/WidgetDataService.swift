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
                let coverFileName = coverImageFileName(for: roll.filmName)
                return WidgetRollData(
                    id: roll.id.uuidString,
                    filmName: roll.filmName,
                    photoCount: (roll.frames ?? []).filter { $0.photoAssetID != nil }.count,
                    capacity: roll.capacity,
                    status: roll.status,
                    coverImageFile: coverFileName
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

        // Snapshot used by App Intents / Siri Shortcuts (works without launching
        // the app). Includes every roll plus which one is currently shooting.
        let activeRoll = rolls
            .filter { ($0.rollStatus == .inProgress) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        let allItems = rolls
            .sorted { $0.startDate > $1.startDate }
            .map { roll in
                IntentRollItem(
                    id: roll.id.uuidString,
                    filmName: roll.filmName,
                    photoCount: (roll.frames ?? []).filter { $0.photoAssetID != nil }.count,
                    capacity: roll.capacity,
                    status: roll.status
                )
            }
        let intentData = IntentSnapshot(activeRollID: activeRoll?.id.uuidString, allRolls: allItems)
        if let encoded = try? JSONEncoder().encode(intentData) {
            defaults.set(encoded, forKey: "intentData")
        }

        WidgetCenter.shared.reloadAllTimelines()

        // Cache cover images for widget
        Task {
            await cacheCoverImages(for: Array(recentRolls))
        }
    }

    private static func coverImageFileName(for filmName: String) -> String? {
        guard let stock = FilmStock.allStocks.first(where: { stock in
            stock.displayName.lowercased() == filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == filmName.lowercased()
        }), stock.githubCoverUrl != nil else { return nil }
        let safeName = filmName.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return "cover_\(safeName).jpg"
    }

    private static func cacheCoverImages(for rolls: [WidgetRollData]) async {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.williamcachamwri.FilmVault"
        ) else { return }

        let cacheDir = containerURL.appendingPathComponent("WidgetCovers")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        for roll in rolls {
            guard let fileName = roll.coverImageFile else { continue }
            let fileURL = cacheDir.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: fileURL.path) { continue }

            guard let stock = FilmStock.allStocks.first(where: { stock in
                stock.displayName.lowercased() == roll.filmName.lowercased() ||
                "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
            }),
            let coverUrlString = stock.githubCoverUrl,
            let url = URL(string: coverUrlString) else { continue }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: fileURL)
            } catch {
                continue
            }
        }
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
    let coverImageFile: String?
}

// MARK: - App Intents snapshot

struct IntentSnapshot: Codable {
    let activeRollID: String?
    let allRolls: [IntentRollItem]
}

struct IntentRollItem: Codable {
    let id: String
    let filmName: String
    let photoCount: Int
    let capacity: Int
    let status: String
}
