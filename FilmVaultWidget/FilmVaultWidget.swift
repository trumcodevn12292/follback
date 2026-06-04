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
    let recentRolls: [WidgetRollItem]
}

struct WidgetRollItem: Codable, Identifiable {
    let id: String
    let filmName: String
    let photoCount: Int
    let capacity: Int
    let status: String
    let coverImageFile: String?

    enum CodingKeys: String, CodingKey {
        case id, filmName, photoCount, capacity, status, coverImageFile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        filmName = try container.decode(String.self, forKey: .filmName)
        photoCount = try container.decode(Int.self, forKey: .photoCount)
        capacity = try container.decode(Int.self, forKey: .capacity)
        status = try container.decode(String.self, forKey: .status)
        coverImageFile = try container.decodeIfPresent(String.self, forKey: .coverImageFile)
    }
}

// MARK: - Timeline Provider

struct FilmVaultTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FilmVaultEntry {
        FilmVaultEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FilmVaultEntry) -> Void) {
        let data = loadWidgetData()
        completion(FilmVaultEntry(date: Date(), data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FilmVaultEntry>) -> Void) {
        let data = loadWidgetData()
        let entry = FilmVaultEntry(date: Date(), data: data)
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
}

extension WidgetRollItem {
    init(id: String, filmName: String, photoCount: Int, capacity: Int, status: String, coverImageFile: String? = nil) {
        self.id = id
        self.filmName = filmName
        self.photoCount = photoCount
        self.capacity = capacity
        self.status = status
        self.coverImageFile = coverImageFile
    }
}

extension FilmVaultWidgetData {
    static var placeholder: FilmVaultWidgetData {
        FilmVaultWidgetData(
            totalRolls: 5,
            totalPhotos: 128,
            recentRolls: [
                WidgetRollItem(id: "1", filmName: "Portra 400", photoCount: 32, capacity: 36, status: "completed"),
                WidgetRollItem(id: "2", filmName: "HP5 Plus", photoCount: 24, capacity: 36, status: "inProgress"),
                WidgetRollItem(id: "3", filmName: "Ektar 100", photoCount: 36, capacity: 36, status: "developed"),
                WidgetRollItem(id: "4", filmName: "Gold 200", photoCount: 12, capacity: 36, status: "inProgress"),
                WidgetRollItem(id: "5", filmName: "Tri-X 400", photoCount: 36, capacity: 36, status: "completed"),
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

    // MARK: - Small Widget
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image("WidgetAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text("FilmVault")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Stats
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(entry.data.totalRolls)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(WL("rolls"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Mini progress bar
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(WL("%d photos", entry.data.totalPhotos))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.04, green: 0.04, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Medium Widget
    private var mediumWidget: some View {
        HStack(spacing: 0) {
            // Left: Stats
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image("WidgetAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    Text("FilmVault")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Button(intent: RefreshWidgetIntent()) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.data.totalRolls)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(WL("%d photos", entry.data.totalPhotos))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)

            // Divider
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right: Roll list
            VStack(alignment: .leading, spacing: 7) {
                ForEach(entry.data.recentRolls.prefix(4)) { roll in
                    rollRowMedium(roll)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.04, green: 0.04, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Large Widget
    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image("WidgetAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text("FilmVault")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(intent: RefreshWidgetIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                HStack(spacing: 12) {
                    statBadge(value: "\(entry.data.totalRolls)", label: WL("rolls"), color: .white)
                    statBadge(value: "\(entry.data.totalPhotos)", label: WL("photos"), color: .orange)
                }
            }

            // Separator
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 12)

            // Roll list
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(entry.data.recentRolls.prefix(6).enumerated()), id: \.element.id) { index, roll in
                    if let url = URL(string: "filmvault://roll/\(roll.id)") {
                        Link(destination: url) {
                            rollRowLarge(roll)
                        }
                    } else {
                        rollRowLarge(roll)
                    }
                    if index < min(entry.data.recentRolls.count - 1, 5) {
                        Divider()
                            .background(Color.white.opacity(0.04))
                            .padding(.vertical, 6)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.04, green: 0.04, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Lock Screen Widgets

    private var lockScreenCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(entry.data.totalRolls)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var lockScreenRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("FilmVault")
                    .font(.system(size: 12, weight: .bold))
            }
            HStack(spacing: 8) {
                Text(WL("%d rolls", entry.data.totalRolls))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("•")
                    .foregroundColor(.secondary)
                Text(WL("%d photos", entry.data.totalPhotos))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            if let recent = entry.data.recentRolls.first {
                Text(recent.filmName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var lockScreenInline: some View {
        HStack(spacing: 4) {
            Image(systemName: "camera.fill")
            Text(WL("%d rolls • %d photos", entry.data.totalRolls, entry.data.totalPhotos))
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Components

    private func rollRowMedium(_ roll: WidgetRollItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(roll.status))
                .frame(width: 6, height: 6)
            Text(roll.filmName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            Spacer()
            Text("\(roll.photoCount)/\(roll.capacity)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
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

    private func rollRowLarge(_ roll: WidgetRollItem) -> some View {
        HStack(spacing: 10) {
            // Film cover thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [statusColor(roll.status).opacity(0.3), statusColor(roll.status).opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                if let uiImage = loadCoverImage(for: roll) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Text(String(roll.filmName.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor(roll.status))
                }
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(roll.filmName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(WL("%d of %d frames", roll.photoCount, roll.capacity))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: CGFloat(roll.photoCount) / CGFloat(max(roll.capacity, 1)))
                    .stroke(statusColor(roll.status), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
        }
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color.opacity(0.6))
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "inProgress": return .orange
        case "completed": return .green
        case "developed": return .blue
        case "archived": return .gray
        default: return .orange
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
