import WidgetKit
import SwiftUI
import UIKit
import AppIntents

// MARK: - Widget Localization

/// Localizes widget strings using the language the user picked in-app, shared
/// via the App Group (the widget runs in its own process/bundle so it can't use
/// the app's runtime bundle swizzle).
func widgetLanguageCode() -> String {
    UserDefaults(suiteName: "group.com.williamcachamwri.FilmVault")?
        .string(forKey: "appLanguage") ?? "en"
}

func WL(_ key: String) -> String {
    let code = widgetLanguageCode()
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return NSLocalizedString(key, comment: "")
}

func WL(_ key: String, _ args: CVarArg...) -> String {
    String(format: WL(key), arguments: args)
}

// MARK: - Shared Data Model

struct FilmVaultWidgetData: Codable {
    let totalRolls: Int
    let totalPhotos: Int
    let shootingCount: Int
    let toDevelopCount: Int
    let activeRoll: WidgetRollItem?
    let recentRolls: [WidgetRollItem]

    enum CodingKeys: String, CodingKey {
        case totalRolls, totalPhotos, shootingCount, toDevelopCount, activeRoll, recentRolls
    }

    init(totalRolls: Int, totalPhotos: Int, shootingCount: Int, toDevelopCount: Int,
         activeRoll: WidgetRollItem?, recentRolls: [WidgetRollItem]) {
        self.totalRolls = totalRolls
        self.totalPhotos = totalPhotos
        self.shootingCount = shootingCount
        self.toDevelopCount = toDevelopCount
        self.activeRoll = activeRoll
        self.recentRolls = recentRolls
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalRolls = try c.decode(Int.self, forKey: .totalRolls)
        totalPhotos = try c.decode(Int.self, forKey: .totalPhotos)
        shootingCount = try c.decodeIfPresent(Int.self, forKey: .shootingCount) ?? 0
        toDevelopCount = try c.decodeIfPresent(Int.self, forKey: .toDevelopCount) ?? 0
        activeRoll = try c.decodeIfPresent(WidgetRollItem.self, forKey: .activeRoll)
        recentRolls = try c.decodeIfPresent([WidgetRollItem].self, forKey: .recentRolls) ?? []
    }
}

struct WidgetRollItem: Codable, Identifiable {
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

    var framesLeft: Int { max(0, capacity - photoCount) }
    var progress: Double { capacity > 0 ? min(1.0, Double(photoCount) / Double(capacity)) : 0 }

    enum CodingKeys: String, CodingKey {
        case id, filmName, photoCount, capacity, status, coverImageFile, iso, cameraName, format, pushPull
    }

    init(id: String, filmName: String, photoCount: Int, capacity: Int, status: String,
         coverImageFile: String? = nil, iso: Int = 0, cameraName: String? = nil,
         format: String = "", pushPull: String? = nil) {
        self.id = id
        self.filmName = filmName
        self.photoCount = photoCount
        self.capacity = capacity
        self.status = status
        self.coverImageFile = coverImageFile
        self.iso = iso
        self.cameraName = cameraName
        self.format = format
        self.pushPull = pushPull
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        filmName = try container.decode(String.self, forKey: .filmName)
        photoCount = try container.decode(Int.self, forKey: .photoCount)
        capacity = try container.decode(Int.self, forKey: .capacity)
        status = try container.decode(String.self, forKey: .status)
        coverImageFile = try container.decodeIfPresent(String.self, forKey: .coverImageFile)
        iso = try container.decodeIfPresent(Int.self, forKey: .iso) ?? 0
        cameraName = try container.decodeIfPresent(String.self, forKey: .cameraName)
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? ""
        pushPull = try container.decodeIfPresent(String.self, forKey: .pushPull)
    }
}

// MARK: - Timeline Provider

struct FilmVaultTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FilmVaultEntry {
        FilmVaultEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FilmVaultEntry) -> Void) {
        let data = loadWidgetData()
        let page = WidgetPageStore.clampedPage(recentCount: data.recentRolls.count)
        completion(FilmVaultEntry(date: Date(), data: data, recentPage: page))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FilmVaultEntry>) -> Void) {
        let data = loadWidgetData()
        let page = WidgetPageStore.clampedPage(recentCount: data.recentRolls.count)
        let entry = FilmVaultEntry(date: Date(), data: data, recentPage: page)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadWidgetData() -> FilmVaultWidgetData {
        guard let defaults = UserDefaults(suiteName: "group.com.williamcachamwri.FilmVault"),
              let jsonData = defaults.data(forKey: "widgetData"),
              let data = try? JSONDecoder().decode(FilmVaultWidgetData.self, from: jsonData) else {
            return .placeholder
        }
        return data
    }
}

// MARK: - Timeline Entry

struct FilmVaultEntry: TimelineEntry {
    let date: Date
    let data: FilmVaultWidgetData
    var recentPage: Int = 0
}

extension FilmVaultWidgetData {
    static var placeholder: FilmVaultWidgetData {
        FilmVaultWidgetData(
            totalRolls: 12,
            totalPhotos: 248,
            shootingCount: 2,
            toDevelopCount: 3,
            activeRoll: WidgetRollItem(id: "2", filmName: "HP5 Plus", photoCount: 24, capacity: 36, status: "In Progress", coverImageFile: nil, iso: 400, cameraName: "Nikon FM2", format: "35mm", pushPull: "+1"),
            recentRolls: [
                WidgetRollItem(id: "1", filmName: "Portra 400", photoCount: 32, capacity: 36, status: "Completed", iso: 400, cameraName: "Canon AE-1", format: "35mm"),
                WidgetRollItem(id: "2", filmName: "HP5 Plus", photoCount: 24, capacity: 36, status: "In Progress", iso: 400, cameraName: "Nikon FM2", format: "35mm", pushPull: "+1"),
                WidgetRollItem(id: "3", filmName: "Ektar 100", photoCount: 36, capacity: 36, status: "Developed", iso: 100, cameraName: "Leica M6", format: "35mm"),
                WidgetRollItem(id: "4", filmName: "Gold 200", photoCount: 12, capacity: 36, status: "In Progress", iso: 200, cameraName: "Olympus MJU", format: "35mm"),
                WidgetRollItem(id: "5", filmName: "Tri-X 400", photoCount: 36, capacity: 36, status: "Completed", iso: 400, cameraName: "Pentax K1000", format: "35mm"),
            ]
        )
    }
}

// MARK: - Widget Views

struct FilmVaultWidgetEntryView: View {
    var entry: FilmVaultEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryCircular:
            lockScreenCircular
        case .accessoryRectangular:
            lockScreenRectangular
        case .accessoryInline:
            lockScreenInline
        default:
            smallWidget
        }
    }

    // MARK: - Shared pieces

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.09, green: 0.09, blue: 0.12), Color(red: 0.03, green: 0.03, blue: 0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func headerBar(small: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image("WidgetAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: small ? 14 : 16, height: small ? 14 : 16)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text("FilmVault")
                .font(.system(size: small ? 12 : 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
            Spacer()
            Button(intent: RefreshWidgetIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: small ? 10 : 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
    }

    private func metaLine(_ roll: WidgetRollItem, size: CGFloat = 11) -> some View {
        HStack(spacing: 5) {
            Text("ISO \(roll.iso)")
            if !roll.format.isEmpty {
                Text("•")
                Text(roll.format)
            }
            if let cam = roll.cameraName, !cam.isEmpty {
                Text("•")
                Text(cam).lineLimit(1)
            }
            if let pp = roll.pushPull, !pp.isEmpty {
                Text("•")
                Text(pp).foregroundColor(.orange)
            }
        }
        .font(.system(size: size))
        .foregroundColor(.white.opacity(0.5))
        .lineLimit(1)
    }

    private func progressRing(_ roll: WidgetRollItem, size: CGFloat, line: CGFloat = 3) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: line)
            Circle()
                .trim(from: 0, to: CGFloat(roll.progress))
                .stroke(statusColor(roll.status), style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(roll.photoCount)")
                    .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Rectangle().fill(Color.white.opacity(0.25)).frame(width: size * 0.26, height: 1)
                Text("\(roll.capacity)")
                    .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
    }

    private func progressBar(_ roll: WidgetRollItem, height: CGFloat = 5) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(statusColor(roll.status))
                    .frame(width: max(0, geo.size.width * CGFloat(roll.progress)))
            }
        }
        .frame(height: height)
    }

    private func statChip(_ value: String, _ label: String, _ color: Color, _ systemName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func nowShootingTag() -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color.orange).frame(width: 6, height: 6)
            Text(WL("Now Shooting"))
                .font(.system(size: 10, weight: .bold))
                .kerning(0.5)
                .foregroundColor(.orange)
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        Group {
            if let roll = entry.data.activeRoll {
                smallActive(roll)
            } else {
                smallStats
            }
        }
        .padding(14)
        .containerBackground(for: .widget) { background }
        .widgetURL(URL(string: smallDeepLink))
    }

    private var smallDeepLink: String {
        if let roll = entry.data.activeRoll { return "filmvault://roll/\(roll.id)" }
        return "filmvault://rolls"
    }

    private func smallActive(_ roll: WidgetRollItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                nowShootingTag()
                Spacer()
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            Text(roll.filmName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            metaLine(roll, size: 10)

            Spacer(minLength: 6)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(roll.photoCount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("/\(roll.capacity)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(WL("%d left", roll.framesLeft))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            progressBar(roll)
                .padding(.top, 5)
        }
    }

    private var smallStats: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar(small: true)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(entry.data.totalRolls)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(WL("rolls"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text(WL("%d photos", entry.data.totalPhotos))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }
            .padding(.top, 5)
            HStack(spacing: 10) {
                miniStat("\(entry.data.shootingCount)", WL("Shooting"), .orange)
                miniStat("\(entry.data.toDevelopCount)", WL("To Develop"), .green)
            }
            .padding(.top, 8)
        }
    }

    private func miniStat(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 12) {
            mediumLeft
                .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(spacing: 7) {
                statChip("\(entry.data.totalRolls)", WL("rolls"), .white, "film")
                statChip("\(entry.data.totalPhotos)", WL("photos"), .orange, "camera.fill")
                statChip("\(entry.data.shootingCount)", WL("Shooting"), .orange, "dot.radiowaves.left.and.right")
                statChip("\(entry.data.toDevelopCount)", WL("To Develop"), .green, "timer")
            }
            .frame(width: 138)
        }
        .padding(14)
        .containerBackground(for: .widget) { background }
        .widgetURL(URL(string: smallDeepLink))
    }

    @ViewBuilder
    private var mediumLeft: some View {
        if let roll = entry.data.activeRoll {
            VStack(alignment: .leading, spacing: 0) {
                nowShootingTag()
                Spacer(minLength: 6)
                HStack(spacing: 12) {
                    progressRing(roll, size: 58, line: 5)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(roll.filmName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(WL("%d left", roll.framesLeft))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(statusColor(roll.status))
                    }
                }
                Spacer(minLength: 6)
                metaLine(roll, size: 11)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                headerBar()
                Spacer()
                Text("\(entry.data.totalRolls)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(WL("%d photos", entry.data.totalPhotos))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                Spacer()
                Text(WL("No roll in progress right now."))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Large Widget

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar()

            HStack(spacing: 8) {
                statChip("\(entry.data.totalRolls)", WL("rolls"), .white, "film")
                statChip("\(entry.data.totalPhotos)", WL("photos"), .orange, "camera.fill")
            }
            .padding(.top, 10)
            HStack(spacing: 8) {
                statChip("\(entry.data.shootingCount)", WL("Shooting"), .orange, "dot.radiowaves.left.and.right")
                statChip("\(entry.data.toDevelopCount)", WL("To Develop"), .green, "timer")
            }
            .padding(.top, 7)

            if let roll = entry.data.activeRoll {
                if let url = URL(string: "filmvault://roll/\(roll.id)") {
                    Link(destination: url) { activeBanner(roll) }
                } else {
                    activeBanner(roll)
                }
            }

            let pageSize = 2
            let allRecent = entry.data.recentRolls
            let totalPages = max(1, (allRecent.count + pageSize - 1) / pageSize)
            let page = min(max(0, entry.recentPage), totalPages - 1)
            let start = page * pageSize
            let pageItems = Array(allRecent[start..<min(start + pageSize, allRecent.count)].enumerated())

            HStack(spacing: 8) {
                Text(WL("Recent"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .kerning(0.6)
                Spacer()
                if totalPages > 1 {
                    Text("\(page + 1)/\(totalPages)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .monospacedDigit()
                    Button(intent: WidgetRecentPrevIntent()) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(page > 0 ? .orange : .white.opacity(0.18))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    Button(intent: WidgetRecentNextIntent()) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(page < totalPages - 1 ? .orange : .white.opacity(0.18))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(pageItems, id: \.element.id) { index, roll in
                    if let url = URL(string: "filmvault://roll/\(roll.id)") {
                        Link(destination: url) { rollRow(roll) }
                    } else {
                        rollRow(roll)
                    }
                    if index < pageItems.count - 1 {
                        Divider().background(Color.white.opacity(0.05)).padding(.vertical, 5)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) { background }
    }

    private func activeBanner(_ roll: WidgetRollItem) -> some View {
        HStack(spacing: 12) {
            progressRing(roll, size: 50, line: 4)
            VStack(alignment: .leading, spacing: 3) {
                nowShootingTag()
                Text(roll.filmName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                metaLine(roll, size: 10)
            }
            Spacer()
            Text(WL("%d left", roll.framesLeft))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor(roll.status))
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 0.5)
                )
        )
        .padding(.top, 10)
    }

    private func rollRow(_ roll: WidgetRollItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [statusColor(roll.status).opacity(0.3), statusColor(roll.status).opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                if let uiImage = loadCoverImage(for: roll) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    Text(String(roll.filmName.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor(roll.status))
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(roll.filmName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(statusColor(roll.status)).frame(width: 5, height: 5)
                    Text(WL(statusDisplayKey(roll.status)))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                    Text("·").foregroundColor(.white.opacity(0.3))
                    Text(WL("%d of %d frames", roll.photoCount, roll.capacity))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            Spacer()

            progressRing(roll, size: 24, line: 2.5)
        }
    }

    private func loadCoverImage(for roll: WidgetRollItem) -> UIImage? {
        guard let fileName = roll.coverImageFile,
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.williamcachamwri.FilmVault"
              ) else { return nil }
        let fileURL = containerURL.appendingPathComponent("WidgetCovers").appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Lock Screen Widgets

    private var lockScreenCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let roll = entry.data.activeRoll {
                Circle()
                    .trim(from: 0, to: CGFloat(roll.progress))
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                VStack(spacing: 0) {
                    Text("\(roll.photoCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("\(roll.capacity)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(entry.data.totalRolls)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var lockScreenRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let roll = entry.data.activeRoll {
                HStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(WL("Now Shooting"))
                        .font(.system(size: 12, weight: .bold))
                }
                Text(roll.filmName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(roll.photoCount)/\(roll.capacity)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(WL("%d left", roll.framesLeft))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("FilmVault")
                        .font(.system(size: 12, weight: .bold))
                }
                HStack(spacing: 8) {
                    Text(WL("%d rolls", entry.data.totalRolls))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("•").foregroundColor(.secondary)
                    Text(WL("%d photos", entry.data.totalPhotos))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                if let recent = entry.data.recentRolls.first {
                    Text(recent.filmName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var lockScreenInline: some View {
        HStack(spacing: 4) {
            if let roll = entry.data.activeRoll {
                Image(systemName: "film")
                Text("\(roll.filmName) \(roll.photoCount)/\(roll.capacity)")
            } else {
                Image(systemName: "camera.fill")
                Text(WL("%d rolls • %d photos", entry.data.totalRolls, entry.data.totalPhotos))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Status helpers

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "inprogress", "in progress": return .orange
        case "completed": return .green
        case "developed": return .blue
        case "archived": return .gray
        default: return .orange
        }
    }

    private func statusDisplayKey(_ status: String) -> String {
        switch status.lowercased() {
        case "inprogress", "in progress": return "Shooting"
        case "completed": return "Shot"
        case "developed": return "Developed"
        case "archived": return "Archived"
        default: return "Shooting"
        }
    }
}

// MARK: - Refresh Intent

struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Widget"
    static var description = IntentDescription("Refreshes the FilmVault widget data.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Recent rolls pagination (large widget)

/// Persists which "page" of recent rolls the large widget is showing, shared via
/// the App Group so the up/down buttons can advance it without launching the app.
enum WidgetPageStore {
    static let suiteName = "group.com.williamcachamwri.FilmVault"
    static let key = "widgetRecentPage"
    static let pageSize = 2

    static func clampedPage(recentCount: Int) -> Int {
        let stored = UserDefaults(suiteName: suiteName)?.integer(forKey: key) ?? 0
        let maxPage = recentCount <= 0 ? 0 : (recentCount - 1) / pageSize
        return min(max(0, stored), maxPage)
    }

    static func advance(by delta: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        var count = 0
        if let jsonData = defaults.data(forKey: "widgetData"),
           let data = try? JSONDecoder().decode(FilmVaultWidgetData.self, from: jsonData) {
            count = data.recentRolls.count
        }
        let maxPage = count <= 0 ? 0 : (count - 1) / pageSize
        let current = defaults.integer(forKey: key)
        defaults.set(min(max(0, current + delta), maxPage), forKey: key)
    }
}

struct WidgetRecentNextIntent: AppIntent {
    static var title: LocalizedStringResource = "Show next rolls"
    static var description = IntentDescription("Shows the next page of recent rolls in the widget.")

    func perform() async throws -> some IntentResult {
        WidgetPageStore.advance(by: 1)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WidgetRecentPrevIntent: AppIntent {
    static var title: LocalizedStringResource = "Show previous rolls"
    static var description = IntentDescription("Shows the previous page of recent rolls in the widget.")

    func perform() async throws -> some IntentResult {
        WidgetPageStore.advance(by: -1)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Widget Definition

struct FilmVaultWidget: Widget {
    let kind: String = "FilmVaultWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FilmVaultTimelineProvider()) { entry in
            FilmVaultWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FilmVault")
        .description("View your film rolls and photo count.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
