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
                .padding(.bottom, 100)
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.filmText, Color.filmText.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("Preferences & stats")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -15)
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
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.15), color.opacity(0.03)],
                            center: .center,
                            startRadius: 5,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.filmText)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .filmCard(cornerRadius: 18)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.filmAccent, Color.filmGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Film Activity")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.filmSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

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

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.filmAccent.opacity(0.15), Color.filmGold.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 18))
                                .foregroundColor(Color.filmAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FilmVault")
                                .foregroundColor(Color.filmText)
                                .font(.system(size: 18, weight: .bold, design: .serif))
                            Text("A journal for your analog photography.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.filmSecondary)
                        }
                    }
                    Spacer()
                    Text("2.0")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.filmAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.filmAccent.opacity(0.1))
                        )
                }
            }
            .padding(18)
            .filmCard(cornerRadius: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Data")

            VStack(spacing: 0) {
                rowButton("Export Rolls JSON", icon: "arrow.up.doc", color: Color.filmAccent)
                Divider().background(Color.filmBorder)
                rowButton("Import Rolls JSON", icon: "arrow.down.doc", color: Color.filmGold)
            }
            .padding(.horizontal, 18)
            .filmCard(cornerRadius: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Appearance")

            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.filmAccent.opacity(0.15), Color.clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: theme.isDarkMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.filmAccent, Color.filmGold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    Text("Dark Mode")
                        .font(.system(size: 16, weight: .semibold))
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
            .filmCard(cornerRadius: 18)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: appeared)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func rowButton(_ title: String, icon: String, color: Color) -> some View {
        Button {} label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
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
        let gradientColors = [UIColor(Color.filmAccent.opacity(0.3)).cgColor, UIColor.clear.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: nil, colors: gradientColors, locations: nil) {
            dataSet.fill = LinearChartFill(gradient: gradient, angle: 90)
        }
        let chartData = LineChartData(dataSet: dataSet)
        let labels = sortedKeys.map { "\($0.month!)/\($0.year! % 100)" }
        uiView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        uiView.data = chartData
    }
}
