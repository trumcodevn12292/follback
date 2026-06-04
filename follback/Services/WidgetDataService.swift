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
            .map { widgetRollData(for: $0) }

        // Roll currently being shot (most recently updated in-progress roll),
        // plus quick counts so the widget can surface live status at a glance.
        let activeRollModel = rolls
            .filter { $0.rollStatus == .inProgress && $0.filledFrames < $0.capacity }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        let shootingCount = rolls.filter { $0.rollStatus == .inProgress && $0.filledFrames < $0.capacity }.count
        let toDevelopCount = rolls.filter { $0.rollStatus == .completed }.count

        let widgetData = WidgetSharedData(
            totalRolls: totalRolls,
            totalPhotos: totalPhotos,
            shootingCount: shootingCount,
            toDevelopCount: toDevelopCount,
            activeRoll: activeRollModel.map { widgetRollData(for: $0) },
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

    private static func widgetRollData(for roll: Roll) -> WidgetRollData {
        WidgetRollData(
            id: roll.id.uuidString,
            filmName: roll.filmName,
            photoCount: (roll.frames ?? []).filter { $0.photoAssetID != nil }.count,
            capacity: roll.capacity,
            status: roll.status,
            coverImageFile: coverImageFileName(for: roll.filmName),
            iso: roll.iso,
            cameraName: cameraName(roll.camera),
            format: roll.filmFormat.displayName,
            pushPull: pushPullText(roll.pushPull)
        )
    }

    private static func cameraName(_ camera: Camera?) -> String? {
        guard let camera else { return nil }
        let combined = "\(camera.brand) \(camera.name)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? nil : combined
    }

    private static func pushPullText(_ value: Float) -> String? {
        guard value != 0 else { return nil }
        let rounded = (value * 10).rounded() / 10
        let number: String
        if rounded == rounded.rounded() {
            number = String(Int(rounded))
        } else {
            number = String(format: "%.1f", rounded)
        }
        return rounded > 0 ? "+\(number)" : number
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
    let shootingCount: Int
    let toDevelopCount: Int
    let activeRoll: WidgetRollData?
    let recentRolls: [WidgetRollData]
}

struct WidgetRollData: Codable {
    let id: String
    let filmName: String
    let photoCount: Int
    let capacity: Int
    let status: String
    let coverImageFile: String?
    let iso: Int
    let cameraName: String?
    let format: String
    let pushPull: String?
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
