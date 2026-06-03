import WidgetKit
import SwiftUI

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
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
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

extension FilmVaultWidgetData {
    static var placeholder: FilmVaultWidgetData {
        FilmVaultWidgetData(
            totalRolls: 5,
            totalPhotos: 128,
            recentRolls: [
                WidgetRollItem(id: "1", filmName: "Portra 400", photoCount: 32, capacity: 36, status: "completed"),
                WidgetRollItem(id: "2", filmName: "HP5 Plus", photoCount: 24, capacity: 36, status: "inProgress"),
                WidgetRollItem(id: "3", filmName: "Ektar 100", photoCount: 36, capacity: 36, status: "developed"),
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
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "film")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                Text("FilmVault")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(entry.data.totalRolls)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("rolls")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                HStack(spacing: 4) {
                    Text("\(entry.data.totalPhotos)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("photos")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    // MARK: - Medium Widget
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "film")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                    Text("FilmVault")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.data.totalRolls) rolls")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(entry.data.totalPhotos) photos")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.data.recentRolls.prefix(3)) { roll in
                    rollRow(roll)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    // MARK: - Large Widget
    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "film")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                Text("FilmVault")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.data.totalRolls) rolls")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(entry.data.totalPhotos) photos")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }

            Divider().background(Color.gray.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.data.recentRolls.prefix(6)) { roll in
                    rollRowLarge(roll)
                }
            }

            Spacer()
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    // MARK: - Row Components

    private func rollRow(_ roll: WidgetRollItem) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(roll.status))
                .frame(width: 6, height: 6)
            Text(roll.filmName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Text("\(roll.photoCount)/\(roll.capacity)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    private func rollRowLarge(_ roll: WidgetRollItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(roll.status))
                .frame(width: 8, height: 8)
            Text(roll.filmName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Text("\(roll.photoCount)/\(roll.capacity)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
            statusLabel(roll.status)
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

    private func statusLabel(_ status: String) -> some View {
        Text(status == "inProgress" ? "In Progress" :
             status == "completed" ? "Done" :
             status == "developed" ? "Developed" : "Archived")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(statusColor(status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
