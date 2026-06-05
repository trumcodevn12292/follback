import SwiftUI
import SwiftData
import Kingfisher

struct StatisticsView: View {
    @Query(sort: \Roll.createdAt, order: .reverse) private var rolls: [Roll]
    @Query(sort: \Camera.name) private var cameras: [Camera]
    @AppStorage(Money.currencyKey) private var currencyCode = Money.defaultCode
    @ObservedObject private var l10n = LocalizationManager.shared
    @ObservedObject private var labStore = CustomLabStore.shared

    @State private var appeared = false
    @State private var barProgress: CGFloat = 0

    // MARK: - Totals

    private var filmTotal: Double { rolls.compactMap(\.filmCost).reduce(0, +) }
    private var devTotal: Double { rolls.compactMap(\.devCost).reduce(0, +) }
    private var cameraTotal: Double { cameras.compactMap(\.purchasePrice).reduce(0, +) }
    private var grandTotal: Double { filmTotal + devTotal + cameraTotal }

    private struct Breakdown: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let color: Color
    }

    private var breakdown: [Breakdown] {
        [
            Breakdown(label: L("Film"), amount: filmTotal, color: Color.filmText),
            Breakdown(label: L("Develop & scan"), amount: devTotal, color: Color.filmTertiary),
            Breakdown(label: L("Cameras"), amount: cameraTotal, color: Color.filmAccent),
        ].filter { $0.amount > 0 }
    }

    // MARK: - Aggregates

    private var totalRolls: Int { rolls.count }
    private var totalPhotos: Int { rolls.reduce(0) { $0 + $1.filledFrames } }
    private var costPerPhoto: Double? {
        let photos = totalPhotos
        return photos > 0 ? grandTotal / Double(photos) : nil
    }
    private var distinctFilms: Int { Set(rolls.map(\.filmName).filter { !$0.isEmpty }).count }
    private var distinctCameras: Int { Set(rolls.compactMap(\.camera?.id)).count }
    private var distinctLabs: Int { Set(rolls.compactMap(\.labName).filter { !$0.isEmpty }).count }

    // MARK: - Film Stats

    private struct FilmStat: Identifiable {
        let id = UUID()
        let name: String
        let iso: Int
        let format: String
        let rollCount: Int
        let photos: Int
        let totalCost: Double
        let maxRolls: Int
    }

    private var filmStats: [FilmStat] {
        let groups = Dictionary(grouping: rolls.filter { !$0.filmName.isEmpty }) { $0.filmName }
        let maxRolls = groups.values.map(\.count).max() ?? 1
        return groups.map { name, group in
            let sample = group[0]
            return FilmStat(
                name: name,
                iso: sample.iso,
                format: sample.filmFormat.displayName,
                rollCount: group.count,
                photos: group.reduce(0) { $0 + $1.filledFrames },
                totalCost: group.compactMap(\.totalCost).reduce(0, +),
                maxRolls: maxRolls
            )
        }
        .sorted { $0.rollCount != $1.rollCount ? $0.rollCount > $1.rollCount : $0.photos > $1.photos }
    }

    // MARK: - Camera Stats

    private struct CameraStat: Identifiable {
        let id: UUID
        let camera: Camera
        let rollCount: Int
        let photos: Int
        let maxRolls: Int
    }

    private var cameraStats: [CameraStat] {
        let stats = cameras.compactMap { cam -> CameraStat? in
            let used = rolls.filter { $0.camera?.id == cam.id }
            guard !used.isEmpty else { return nil }
            return CameraStat(
                id: cam.id,
                camera: cam,
                rollCount: used.count,
                photos: used.reduce(0) { $0 + $1.filledFrames },
                maxRolls: 0
            )
        }
        .sorted { $0.rollCount != $1.rollCount ? $0.rollCount > $1.rollCount : $0.photos > $1.photos }
        let max = stats.first?.rollCount ?? 1
        return stats.map { CameraStat(id: $0.id, camera: $0.camera, rollCount: $0.rollCount, photos: $0.photos, maxRolls: max) }
    }

    // MARK: - Lab Stats

    private struct LabStat: Identifiable {
        let id = UUID()
        let name: String
        let rollCount: Int
        let maxRolls: Int
    }

    private var labStats: [LabStat] {
        let groups = Dictionary(grouping: rolls.compactMap(\.labName).filter { !$0.isEmpty }) { $0 }
        let max = groups.values.map(\.count).max() ?? 1
        return groups.map { LabStat(name: $0, rollCount: $1.count, maxRolls: max) }
            .sorted { $0.rollCount > $1.rollCount }
    }

    // MARK: - Monthly Cost Data

    private var monthlyCostData: [String: Double] {
        let calendar = Calendar.current
        let fmt = DateFormatter()
        fmt.locale = appLocale()
        let months = fmt.shortMonthSymbols ?? []
        let grouped = Dictionary(grouping: rolls.filter { $0.hasCost }) { roll -> String in
            let comps = calendar.dateComponents([.year, .month], from: roll.startDate)
            let month = comps.month ?? 1
            let year = comps.year ?? 2024
            let m = month > 0 && month <= months.count ? months[month - 1] : "\(month)"
            return "\(m) \(year)"
        }
        return grouped.mapValues { $0.compactMap(\.totalCost).reduce(0, +) }
    }

    // MARK: - Activity & Streak

    private var activityDates: [Date] {
        var dates: [Date] = rolls.map(\.startDate)
        for roll in rolls {
            for frame in roll.frames ?? [] where frame.photoAssetID != nil {
                dates.append(frame.capturedAt ?? frame.createdAt)
            }
        }
        return dates
    }

    private var streakWeeks: Int {
        let cal = Calendar.current
        let weeks = Set(activityDates.compactMap {
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

    // MARK: - Achievements

    private struct Achievement: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let unlocked: Bool
    }

    private var achievements: [Achievement] {
        var list: [Achievement] = []
        for goal in [1, 10, 25, 50, 100] {
            list.append(Achievement(
                icon: "film",
                title: L("%d rolls", goal),
                unlocked: totalRolls >= goal
            ))
        }
        for goal in [100, 500, 1000, 5000] {
            list.append(Achievement(
                icon: "photo.on.rectangle",
                title: L("%d photos", goal),
                unlocked: totalPhotos >= goal
            ))
        }
        for goal in [5, 15, 30] {
            list.append(Achievement(
                icon: "sparkles",
                title: L("%d films", goal),
                unlocked: distinctFilms >= goal
            ))
        }
        let unlocked = list.filter(\.unlocked)
        let locked = list.filter { !$0.unlocked }
        return unlocked + locked
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    ZStack {
                        AuroraGlow(appeared: appeared)
                        totalCard
                    }
                    .modifier(EntranceEffect(appeared: appeared, index: 0))

                    if totalRolls > 0 {
                        statTiles
                            .modifier(EntranceEffect(appeared: appeared, index: 1))

                        achievementsSection
                            .modifier(EntranceEffect(appeared: appeared, index: 2))

                        if !monthlyCostData.isEmpty {
                            costTrendSection
                                .modifier(EntranceEffect(appeared: appeared, index: 3))
                        }

                        if !filmStats.isEmpty {
                            topFilmsSection
                                .modifier(EntranceEffect(appeared: appeared, index: 4))
                        }

                        if !cameraStats.isEmpty {
                            topCamerasSection
                                .modifier(EntranceEffect(appeared: appeared, index: 10))
                        }

                        if !labStats.isEmpty {
                            topLabsSection
                                .modifier(EntranceEffect(appeared: appeared, index: 16))
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 24)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle(L("Insights"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                appeared = true
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.prepare()
                generator.impactOccurred()
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.2)) {
                    barProgress = 1
                }
            }
            .onDisappear {
                appeared = false
                barProgress = 0
            }
        }
    }

    // MARK: - Total Card

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L("Total spent"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.filmTertiary)
                    .kerning(0.8)
                Spacer()
                Text(currencyCode)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.filmTertiary)
                    .kerning(0.8)
            }

            Text(Money.formatNumber(grandTotal))
                .font(.system(size: 44, weight: .heavy))
                .foregroundColor(Color.filmText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if grandTotal > 0 {
                stackedBar
                VStack(spacing: 10) {
                    ForEach(breakdown) { item in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(item.color)
                                .frame(width: 18, height: 18)
                            Text(item.label)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(Money.formatNumber(item.amount))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.filmText)
                        }
                    }
                }
            } else {
                Text(L("Add costs to your rolls and cameras to see your spending."))
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.filmSurface)
        )
    }

    private var stackedBar: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(breakdown) { item in
                    let fraction = grandTotal > 0 ? item.amount / grandTotal : 0
                    Capsule()
                        .fill(item.color)
                        .frame(width: max(6, geo.size.width * fraction - 3))
                }
            }
            .scaleEffect(x: barProgress, anchor: .leading)
            .opacity(barProgress)
        }
        .frame(height: 14)
    }

    // MARK: - Stat Tiles

    private var statTiles: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(totalRolls)", label: L("Rolls"), icon: "film")
            StatTile(value: "\(totalPhotos)", label: L("Photos"), icon: "photo.on.rectangle")
            StatTile(
                value: "\(streakWeeks)",
                label: streakWeeks == 1 ? L("week streak") : L("weeks streak"),
                icon: "flame.fill",
                highlight: streakWeeks > 0
            )
            StatTile(
                value: costPerPhoto.map { Money.formatNumber($0) } ?? "—",
                label: L("cost/photo"),
                icon: "chart.pie.fill"
            )
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        section(title: L("Achievements")) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 12) {
                ForEach(achievements) { badge in
                    VStack(spacing: 8) {
                        Image(systemName: badge.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .symbolVariant(badge.unlocked ? .fill : .none)
                            .foregroundColor(badge.unlocked ? Color.filmAccent : Color.filmTertiary.opacity(0.5))
                            .frame(height: 26)
                        Text(badge.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(badge.unlocked ? Color.filmText : Color.filmTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if badge.unlocked {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.filmAccent)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.filmSurface)
                            .opacity(badge.unlocked ? 1 : 0.55)
                    )
                }
            }
        }
    }

    // MARK: - Cost Trend

    private var costTrendSection: some View {
        section(title: L("Cost trend")) {
            BarChartWrapper(data: monthlyCostData)
                .frame(height: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )
        }
    }

    // MARK: - Top Films

    private var topFilmsSection: some View {
        section(title: L("Most-shot films")) {
            VStack(spacing: 8) {
                ForEach(Array(filmStats.prefix(10).enumerated()), id: \.element.id) { idx, stat in
                    RankingRow(
                        rank: idx + 1,
                        title: stat.name,
                        subtitle: "ISO \(stat.iso) · \(stat.format)",
                        usage: "\(L("%d rolls", stat.rollCount)) · \(L("%d photos", stat.photos))",
                        fraction: Double(stat.rollCount) / Double(stat.maxRolls),
                        thumbnail: { filmThumbnail(for: stat.name) }
                    )
                    .modifier(EntranceEffect(appeared: appeared, index: 4 + idx))
                }
            }
        }
    }

    // MARK: - Top Cameras

    private var topCamerasSection: some View {
        section(title: L("Most-used cameras")) {
            VStack(spacing: 8) {
                ForEach(Array(cameraStats.prefix(10).enumerated()), id: \.element.id) { idx, stat in
                    RankingRow(
                        rank: idx + 1,
                        title: stat.camera.name,
                        subtitle: stat.camera.brand,
                        usage: "\(L("%d rolls", stat.rollCount)) · \(L("%d photos", stat.photos))",
                        fraction: Double(stat.rollCount) / Double(stat.maxRolls),
                        thumbnail: { cameraThumbnail(stat.camera) }
                    )
                    .modifier(EntranceEffect(appeared: appeared, index: 10 + idx))
                }
            }
        }
    }

    // MARK: - Top Labs

    private var topLabsSection: some View {
        section(title: L("Most-used labs")) {
            VStack(spacing: 8) {
                ForEach(Array(labStats.prefix(10).enumerated()), id: \.element.id) { idx, stat in
                    RankingRow(
                        rank: idx + 1,
                        title: stat.name,
                        subtitle: nil,
                        usage: L("%d rolls delivered", stat.rollCount),
                        fraction: Double(stat.rollCount) / Double(stat.maxRolls),
                        thumbnail: { labThumbnail(for: stat.name) }
                    )
                    .modifier(EntranceEffect(appeared: appeared, index: 16 + idx))
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(Color.filmTertiary)
            Text(L("No data yet"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.filmText)
            Text(L("Start shooting and logging your rolls to see insights."))
                .font(.system(size: 14))
                .foregroundColor(Color.filmTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .kerning(0.8)
            content()
        }
    }

    private func filmStock(for name: String) -> FilmStock? {
        FilmStock.allStocks.first {
            $0.displayName.lowercased() == name.lowercased() ||
            "\($0.brand) \($0.name)".lowercased() == name.lowercased()
        }
    }

    private func customFilm(for name: String) -> CustomFilm? {
        CustomFilmStore.shared.films.first { $0.name.lowercased() == name.lowercased() }
    }

    @ViewBuilder
    private func filmThumbnail(for name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.filmSurfaceSecondary)
                .frame(width: 44, height: 44)

            if let custom = customFilm(for: name),
               let data = custom.coverImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let stock = filmStock(for: name),
                      let urlString = stock.githubCoverUrl,
                      let url = URL(string: urlString) {
                KFImage(url)
                    .downsampling(size: CGSize(width: 100, height: 100))
                    .cacheOriginalImage()
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }
        }
    }

    @ViewBuilder
    private func cameraThumbnail(_ camera: Camera) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.filmSurfaceSecondary)
                .frame(width: 44, height: 44)

            if let assetID = camera.photoAssetID, !assetID.isEmpty {
                PhotoThumbnail(assetID: assetID, targetSize: 100)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "camera")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }
        }
    }

    @ViewBuilder
    private func labThumbnail(for name: String) -> some View {
        if let custom = labStore.lab(named: name) {
            CustomLabAvatar(lab: custom, size: 44)
        } else if let filmLab = FilmLab.allLabs.first(where: { $0.name == name }),
                  let urlString = filmLab.logoUrl,
                  let url = URL(string: urlString) {
            KFImage(url)
                .downsampling(size: CGSize(width: 100, height: 100))
                .cacheOriginalImage()
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            LabInitialAvatar(name: name, size: 44)
        }
    }
}

// MARK: - Sub-views

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var highlight: Bool = false

    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(highlight ? Color.filmAccent : Color.filmSecondary)
                .scaleEffect(iconBounce ? 1 : 0.5)
                .opacity(iconBounce ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15), value: iconBounce)
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(Color.filmText)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.filmTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
        )
        .onAppear { iconBounce = true }
        .onDisappear { iconBounce = false }
    }
}

private struct RankingRow<Thumbnail: View>: View {
    let rank: Int
    let title: String
    let subtitle: String?
    let usage: String
    let fraction: Double
    @ViewBuilder let thumbnail: Thumbnail

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.filmTertiary)
                .frame(width: 24, alignment: .leading)

            thumbnail
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmText)
                    .lineLimit(1)

                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(Color.filmTertiary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.filmSurfaceSecondary)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.filmAccent.opacity(0.7))
                            .frame(width: geo.size.width * min(fraction, 1), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Text(usage)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.filmSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.filmSurface)
        )
    }
}

private struct LabInitialAvatar: View {
    let name: String
    var size: CGFloat = 44

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    private var color: Color {
        let hash = abs(name.hashValue) % colors.count
        return colors[hash]
    }

    var body: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
    }
}

private struct AuroraGlow: View {
    let appeared: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.filmAccent.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: phase * 30 - 15, y: -20 + phase * 10)

            Circle()
                .fill(Color.filmGold.opacity(0.06))
                .frame(width: 160, height: 160)
                .blur(radius: 50)
                .offset(x: -20 - phase * 20, y: -10)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

private struct EntranceEffect: ViewModifier {
    let appeared: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.88, anchor: .top)
            .blur(radius: appeared ? 0 : 5)
            .offset(y: appeared ? 0 : 35)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.3)
                    .delay(Double(index) * 0.07),
                value: appeared
            )
    }
}
