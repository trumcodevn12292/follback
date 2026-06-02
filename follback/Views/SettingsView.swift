import SwiftUI
import SwiftData
import DGCharts

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Roll.createdAt, order: .reverse) var rolls: [Roll]
    @Query(sort: \Camera.name) var cameras: [Camera]
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
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
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
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
                .foregroundColor(Color.filmTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -10)
    }

    private var statsCards: some View {
        HStack(spacing: 10) {
            statCard("Rolls", value: "\(rolls.count)", icon: "film", color: Color.filmAccent)
            statCard("Cameras", value: "\(cameras.count)", icon: "camera", color: Color.filmGold)
            statCard("Frames", value: "\(totalFrames)", icon: "photo", color: Color.filmCopper)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
    }

    private var totalFrames: Int {
        rolls.reduce(0) { $0 + ($1.frames?.count ?? 0) }
    }

    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(Color.filmText)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.filmTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                )
        )
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Film Activity")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            LineChartWrapper(rolls: rolls)
                .frame(height: 200)
                .filmCard(cornerRadius: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("About")

            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 18))
                        .foregroundColor(Color.filmAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FilmVault")
                            .foregroundColor(Color.filmText)
                            .font(.system(size: 16, weight: .semibold))
                        Text("Analog photography journal")
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmTertiary)
                    }
                }
                Spacer()
                Text("v3.0")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.filmTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.35).delay(0.1), value: appeared)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Data")

            VStack(spacing: 0) {
                rowButton("Export Rolls JSON", icon: "arrow.up.doc", color: Color.filmAccent)
                Divider().background(Color.filmBorder.opacity(0.3))
                rowButton("Import Rolls JSON", icon: "arrow.down.doc", color: Color.filmAccent)
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.35).delay(0.12), value: appeared)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Appearance")

            HStack {
                HStack(spacing: 10) {
                    Image(systemName: theme.isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.filmAccent)
                    Text("Dark Mode")
                        .font(.system(size: 15, weight: .medium))
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
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.easeOut(duration: 0.35).delay(0.15), value: appeared)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color.filmTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func rowButton(_ title: String, icon: String, color: Color) -> some View {
        Button {} label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(Color.filmText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.filmTertiary.opacity(0.5))
            }
            .padding(.vertical, 13)
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
        chart.xAxis.labelFont = .systemFont(ofSize: 9, weight: .medium)
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.labelTextColor = UIColor(Color.filmTertiary)
        chart.leftAxis.labelFont = .systemFont(ofSize: 9)
        chart.leftAxis.axisMinimum = 0
        chart.rightAxis.enabled = false
        chart.animate(xAxisDuration: 1.2, yAxisDuration: 1.0, easingOption: .easeOutCubic)
        chart.setScaleEnabled(false)
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
        dataSet.circleHoleColor = UIColor(Color.filmBackground)
        dataSet.circleHoleRadius = 2
        dataSet.lineWidth = 2.5
        dataSet.drawValuesEnabled = false
        dataSet.mode = .cubicBezier
        dataSet.drawFilledEnabled = true
        dataSet.fillColor = UIColor(Color.filmAccent.opacity(0.3))
        dataSet.fillAlpha = 0.3
        let chartData = LineChartData(dataSet: dataSet)
        let labels = sortedKeys.map { "\($0.month!)/\($0.year! % 100)" }
        uiView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        uiView.data = chartData
    }
}
