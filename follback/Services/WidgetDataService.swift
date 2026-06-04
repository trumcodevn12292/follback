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
            .prefix(10)
            .map { widgetRollData(for: $0) }

        let activeRollModel = rolls
            .filter { $0.rollStatus == .inProgress && $0.filledFrames < $0.capacity }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
        let shootingCount = rolls.filter { $0.rollStatus == .inProgress && $0.filledFrames < $0.capacity }.count
        let toDevelopCount = rolls.filter { $0.rollStatus == .completed }.count

        // Insights
        let distinctFilms = Set(rolls.map { $0.filmName }.filter { !$0.isEmpty }).count

        let filmCost = rolls.compactMap { $0.filmCost }.reduce(0, +)
        let devCost = rolls.compactMap { $0.devCost }.reduce(0, +)

        let filmStats: [WidgetFilmStatData] = {
            let groups = Dictionary(grouping: rolls.filter { !$0.filmName.isEmpty }) { $0.filmName }
            let stats: [WidgetFilmStatData] = groups.map { name, group in
                let sample = group[0]
                return WidgetFilmStatData(
                    name: name,
                    iso: sample.iso,
                    format: sample.filmFormat.displayName,
                    rollCount: group.count,
                    photos: group.reduce(0) { $0 + $1.filledFrames },
                    coverImageFile: coverImageFileName(for: name)
                )
            }
            return stats
                .sorted { $0.rollCount != $1.rollCount ? $0.rollCount > $1.rollCount : $0.photos > $1.photos }
                .prefix(3)
                .map { $0 }
        }()

        let streakWeeks = computeStreakWeeks(from: rolls)

        let widgetData = WidgetSharedData(
            totalRolls: totalRolls,
            totalPhotos: totalPhotos,
            shootingCount: shootingCount,
            toDevelopCount: toDevelopCount,
            activeRoll: activeRollModel.map { widgetRollData(for: $0) },
            recentRolls: Array(recentRolls),
            distinctFilms: distinctFilms,
            streakWeeks: streakWeeks,
            filmCost: filmCost,
            devCost: devCost,
            filmStats: filmStats
        )

        if let encoded = try? JSONEncoder().encode(widgetData) {
            defaults.set(encoded, forKey: "widgetData")
        }

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

        Task {
            var coversToCache = Array(recentRolls)
            if let active = activeRollModel.map({ widgetRollData(for: $0) }),
               !coversToCache.contains(where: { $0.id == active.id }) {
                coversToCache.append(active)
            }
            await cacheCoverImages(for: coversToCache)
        }
    }

    // MARK: - Insights

    private static func computeStreakWeeks(from rolls: [Roll]) -> Int {
        var dates: [Date] = rolls.map { $0.startDate }
        for roll in rolls {
            for frame in roll.frames ?? [] where frame.photoAssetID != nil {
                dates.append(frame.capturedAt ?? frame.createdAt)
            }
        }
        let cal = Calendar.current
        let weeks = Set(dates.compactMap {
            cal.dateInterval(of: .weekOfYear, for: $0)?.start
        })
        guard !weeks.isEmpty,
              let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start
        else { return 0 }

        var anchor = thisWeek
        if !weeks.contains(anchor) {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek),
                  weeks.contains(prev) else { return 0 }
            anchor = prev
        }
        var streak = 0
        var cursor: Date? = anchor
        while let c = cursor, weeks.contains(c) {
            streak += 1
            cursor = cal.date(byAdding: .weekOfYear, value: -1, to: c)
        }
        return streak
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

// MARK: - Data Models

struct WidgetSharedData: Codable {
    let totalRolls: Int
    let totalPhotos: Int
    let shootingCount: Int
    let toDevelopCount: Int
    let activeRoll: WidgetRollData?
    let recentRolls: [WidgetRollData]
    let distinctFilms: Int?
    let streakWeeks: Int?
    let filmCost: Double?
    let devCost: Double?
    let filmStats: [WidgetFilmStatData]?

    init(totalRolls: Int, totalPhotos: Int, shootingCount: Int, toDevelopCount: Int,
         activeRoll: WidgetRollData?, recentRolls: [WidgetRollData],
         distinctFilms: Int? = nil, streakWeeks: Int? = nil,
         filmCost: Double? = nil, devCost: Double? = nil,
         filmStats: [WidgetFilmStatData]? = nil) {
        self.totalRolls = totalRolls
        self.totalPhotos = totalPhotos
        self.shootingCount = shootingCount
        self.toDevelopCount = toDevelopCount
        self.activeRoll = activeRoll
        self.recentRolls = recentRolls
        self.distinctFilms = distinctFilms
        self.streakWeeks = streakWeeks
        self.filmCost = filmCost
        self.devCost = devCost
        self.filmStats = filmStats
    }
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

struct WidgetFilmStatData: Codable {
    let name: String
    let iso: Int
    let format: String
    let rollCount: Int
    let photos: Int
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
