import SwiftUI
import SwiftData
import DGCharts

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Query(sort: \Camera.name) var cameras: [Camera]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    statsCards

                    if !rolls.isEmpty {
                        chartSection
                    }

                    aboutCard
                    dataCard
                    appearanceCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 100)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
            Text("Preferences & stats")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var statsCards: some View {
        HStack(spacing: 10) {
            statCard("Rolls", value: "\(rolls.count)", icon: "camera.roll")
            statCard("Cameras", value: "\(cameras.count)", icon: "camera")
            statCard("Frames", value: "\(totalFrames)", icon: "photo")
        }
    }

    private var totalFrames: Int {
        rolls.reduce(0) { $0 + ($1.frames?.count ?? 0) }
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(Color.filmAccent)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color.filmText)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmAccent)
                Text("Film Activity")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            LineChartWrapper(rolls: rolls)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("About")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FilmVault")
                        .foregroundColor(Color.filmText)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                    Spacer()
                    Text("2.0")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.filmSecondary)
                }
                Text("A journal for your analog photography.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.filmSecondary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Data")

            VStack(spacing: 0) {
                rowButton("Export Rolls JSON", icon: "arrow.up.doc")
                Divider().background(Color.filmBorder)
                rowButton("Import Rolls JSON", icon: "arrow.down.doc")
            }
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Appearance")

            HStack {
                HStack(spacing: 10) {
                    Image(systemName: theme.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.filmAccent)
                    Text("Dark Mode")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.filmText)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { theme.isDarkMode },
                    set: { theme.isDarkMode = $0 }
                ))
                    .labelsHidden()
                    .tint(Color.filmAccent)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func rowButton(_ title: String, icon: String) -> some View {
        Button {} label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color.filmAccent)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.filmText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.filmTertiary)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct LineChartWrapper: UIViewRepresentable {
    let rolls: [Roll]

    func makeUIView(context: Context) -> LineChartView {
        let chart = LineChartView()
        chart.backgroundColor = .clear
        chart.drawGridBackgroundEnabled = false
        chart.legend.enabled = false
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.labelTextColor = UIColor(Color.filmTertiary)
        chart.xAxis.labelFont = .systemFont(ofSize: 9)
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.labelTextColor = UIColor(Color.filmTertiary)
        chart.leftAxis.axisMinimum = 0
        chart.rightAxis.enabled = false
        chart.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
        return chart
    }

    func updateUIView(_ uiView: LineChartView, context: Context) {
        var entries: [ChartDataEntry] = []
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: rolls) { roll in
            calendar.dateComponents([.year, .month], from: roll.createdAt)
        }
        let sortedKeys = grouped.keys.sorted { a, b in
            if a.year != b.year { return a.year! < b.year! }
            return a.month! < b.month!
        }
        for (index, key) in sortedKeys.enumerated() {
            let count = Double(grouped[key]?.count ?? 0)
            entries.append(ChartDataEntry(x: Double(index), y: count))
        }
        let dataSet = LineChartDataSet(entries: entries)
        dataSet.colors = [UIColor(Color.filmAccent)]
        dataSet.circleColors = [UIColor(Color.filmAccent)]
        dataSet.circleRadius = 4
        dataSet.lineWidth = 2
        dataSet.drawValuesEnabled = false
        dataSet.mode = .cubicBezier
        let chartData = LineChartData(dataSet: dataSet)
        let labels = sortedKeys.map { "\($0.month!)/\($0.year! % 100)" }
        uiView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        uiView.data = chartData
    }
}
