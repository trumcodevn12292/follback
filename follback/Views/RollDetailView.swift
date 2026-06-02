import SwiftUI
import SwiftData
import DGCharts

enum FrameSheetTarget: Identifiable {
    case existing(Frame)
    case new(Int)
    var id: String {
        switch self {
        case .existing(let f): return f.id.uuidString
        case .new(let n): return "new_\(n)"
        }
    }
}

struct RollDetailView: View {
    @Bindable var roll: Roll
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var frameSheetTarget: FrameSheetTarget?
    @State private var viewerFrame: Frame?
    @State private var selectedTab = 0
    @State private var appeared = false

    private var sortedFrames: [Frame] {
        roll.frames?.sorted(by: { $0.number < $1.number }) ?? []
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroCard

                SegmentedPicker(selection: $selectedTab, options: [("Frames", "square.grid.2x2"), ("Stats", "chart.bar.fill")])
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                if selectedTab == 0 {
                    frameGridContent
                } else {
                    statsContent
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.filmText)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { markDeveloped() } label: {
                        Label("Mark Developed", systemImage: "checkmark.circle")
                    }
                    Button { markInProgress() } label: {
                        Label("Mark In Progress", systemImage: "arrow.clockwise")
                    }
                    Button { archiveRoll() } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.filmText)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $frameSheetTarget) { target in
            switch target {
            case .existing(let frame):
                FrameEditorView(roll: roll, frame: frame)
            case .new(let number):
                FrameEditorView(roll: roll, frameNumber: number)
            }
        }
        .sheet(item: $viewerFrame) { frame in
            FrameViewerView(frame: frame)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(roll.filmName)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(Color.filmText)
                    Text(roll.camera?.name ?? "No camera")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.filmSecondary)
                }
                Spacer()
                statusBadge
            }

            HStack(spacing: 8) {
                infoPill("ISO \(roll.iso)")
                infoPill("\(roll.capacity) frames")
                infoPill(roll.filmFormat.displayName)
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.filmSprocket)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.filmAccent, Color.filmGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(roll.filledFrames) / CGFloat(max(roll.capacity, 1)), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(roll.filledFrames) of \(roll.capacity) frames")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.filmSecondary)
                    Spacer()
                    if roll.pushPull != 0 {
                        Text(String(format: "Push/Pull %+.1f stops", roll.pushPull))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.filmGold)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 52)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var frameGridContent: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(1...roll.capacity, id: \.self) { number in
                if let frame = sortedFrames.first(where: { $0.number == number }) {
                    frameCell(frame: frame)
                } else {
                    emptyCell(number: number)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var statsContent: some View {
        VStack(spacing: 16) {
            if !apertureDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aperture Distribution")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.filmText)
                        .padding(.horizontal, 16)

                    BarChartWrapper(data: apertureDistribution)
                        .frame(height: 220)
                        .padding(.horizontal, 16)
                }
            }

            HStack(spacing: 12) {
                statCard(title: "Filled", value: "\(roll.filledFrames)", icon: "photo.fill")
                statCard(title: "Empty", value: "\(roll.capacity - roll.filledFrames)", icon: "square.dashed")
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color.filmAccent)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.filmText)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.filmSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
        )
    }

    private var apertureDistribution: [String: Double] {
        var counts: [String: Double] = [:]
        for frame in sortedFrames {
            if let ap = frame.apertureDisplay {
                counts[ap, default: 0] += 1
            }
        }
        return counts
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.filmAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.filmAccent.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(Color.filmAccent.opacity(0.2), lineWidth: 0.5)
            )
    }

    private var statusBadge: some View {
        Text(roll.rollStatus.displayName)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.25), lineWidth: 0.5)
            )
    }

    private var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .developed: return Color.filmSuccess
        case .archived: return Color.filmTertiary
        }
    }

    private func frameCell(frame: Frame) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.filmSprocket)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("#\(frame.number)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.5))
                    )

                if let ap = frame.apertureDisplay, let sh = frame.shutterDisplay {
                    Text("\(ap) \(sh)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.5))
                        )
                }
            }
            .padding(8)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            viewerFrame = frame
        }
    }

    private func emptyCell(number: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.filmSprocket)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.filmBorder, lineWidth: 1)
                )

            Text("\(number)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color.filmTertiary.opacity(0.4))
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            frameSheetTarget = .new(number)
        }
    }

    private func markDeveloped() {
        roll.updateStatus(.developed)
        try? modelContext.save()
    }

    private func markInProgress() {
        roll.updateStatus(.inProgress)
        try? modelContext.save()
    }

    private func archiveRoll() {
        roll.updateStatus(.archived)
        try? modelContext.save()
        dismiss()
    }
}

struct SegmentedPicker: View {
    @Binding var selection: Int
    let options: [(String, String)]
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<options.count, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: options[index].1)
                            .font(.system(size: 14))
                        Text(options[index].0)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(selection == index ? Color.filmBackground : Color.filmSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.filmAccent)
                                    .matchedGeometryEffect(id: "pickerBg", in: animation)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.filmBorder, lineWidth: 0.5)
        )
    }
}

struct BarChartWrapper: UIViewRepresentable {
    let data: [String: Double]

    func makeUIView(context: Context) -> BarChartView {
        let chart = BarChartView()
        chart.backgroundColor = .clear
        chart.drawGridBackgroundEnabled = false
        chart.drawBarShadowEnabled = false
        chart.drawValueAboveBarEnabled = true
        chart.legend.enabled = false
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.labelTextColor = UIColor(Color.filmTertiary)
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.labelTextColor = UIColor(Color.filmTertiary)
        chart.leftAxis.axisMinimum = 0
        chart.rightAxis.enabled = false
        chart.animate(yAxisDuration: 0.8, easingOption: .easeOutBack)
        return chart
    }

    func updateUIView(_ uiView: BarChartView, context: Context) {
        var entries: [BarChartDataEntry] = []
        let labels = Array(data.keys).sorted()
        for (index, key) in labels.enumerated() {
            entries.append(BarChartDataEntry(x: Double(index), y: data[key] ?? 0))
        }
        let dataSet = BarChartDataSet(entries: entries)
        dataSet.colors = [UIColor(Color.filmAccent)]
        dataSet.valueTextColor = UIColor(Color.filmTertiary)
        dataSet.valueFont = .systemFont(ofSize: 10)
        dataSet.cornerRadius = 4
        let chartData = BarChartData(dataSet: dataSet)
        uiView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        uiView.data = chartData
    }
}
