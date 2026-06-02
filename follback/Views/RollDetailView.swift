import SwiftUI
import SwiftData
import DGCharts

enum FrameSheetTarget: Identifiable {
    case new(Int)
    case edit(Frame)
    var id: String {
        switch self {
        case .new(let num): return "new_\(num)"
        case .edit(let frame): return "edit_\(frame.id.uuidString)"
        }
    }
}

struct RollDetailView: View {
    @Bindable var roll: Roll
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewerFrame: Frame?
    @State private var frameSheetTarget: FrameSheetTarget?
    @State private var selectedTab = 0
    @State private var appeared = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerBar
                heroCard
                tabPicker
                tabContent
            }
            .padding(.bottom, 100)
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $frameSheetTarget) { target in
            NavigationStack {
                switch target {
                case .new(let num):
                    FrameEditorView(roll: roll, currentNumber: num)
                case .edit(let frame):
                    FrameEditorView(roll: roll, frame: frame, currentNumber: frame.number)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewerFrame) { frame in
            FrameViewerView(frame: frame)
        }
        .alert("Delete Roll?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(roll)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This will permanently delete \"\(roll.filmName)\" and all its frames.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.filmSurface)
                            .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                    )
            }
            Spacer()

            Menu {
                if roll.rollStatus == .inProgress {
                    Button { markDeveloped() } label: { Label("Mark Developed", systemImage: "checkmark.seal") }
                }
                if roll.rollStatus == .developed {
                    Button { markInProgress() } label: { Label("Mark Active", systemImage: "play") }
                }
                Button { archiveRoll() } label: { Label("Archive", systemImage: "archivebox") }
                Button(role: .destructive) { showDeleteAlert = true } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.filmSurface)
                            .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(roll.filmName)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(Color.filmText)
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.filmAccent)
                        Text(roll.camera?.name ?? "No camera")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.filmSecondary)
                    }
                }
                Spacer()
                statusBadge
            }

            HStack(spacing: 8) {
                specPill(icon: "film", text: "ISO \(roll.iso)")
                specPill(icon: "square.grid.2x2", text: "\(roll.capacity)")
                specPill(icon: "viewfinder", text: roll.filmFormat.displayName)
                if roll.evCompensation != 0 {
                    specPill(icon: "plusminus", text: String(format: "%+.1f EV", roll.evCompensation))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.filmSprocket)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    colors: [Color.filmAccent, Color.filmGold],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(0, geo.size.width * CGFloat(roll.filledFrames) / CGFloat(max(roll.capacity, 1))),
                                height: 8
                            )
                            .shadow(color: Color.filmAccent.opacity(0.4), radius: 8, x: 0, y: 2)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: roll.filledFrames)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(roll.filledFrames)/\(roll.capacity) frames exposed")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.filmTertiary)
                    Spacer()
                    if roll.pushPull != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 10))
                            Text("Push/Pull \(String(format: "%+.1f", roll.pushPull))")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(Color.filmGold)
                    }
                }
            }

            if !roll.notes.isEmpty {
                Text(roll.notes)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
                    .lineSpacing(4)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .filmCard(cornerRadius: 24)
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(roll.rollStatus.displayName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(statusColor.opacity(0.1)))
        .overlay(Capsule().stroke(statusColor.opacity(0.2), lineWidth: 0.5))
    }

    private func specPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color.filmAccent.opacity(0.7))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.filmSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.filmAccent.opacity(0.06))
                .overlay(Capsule().stroke(Color.filmAccent.opacity(0.12), lineWidth: 0.5))
        )
    }

    private var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .developed: return Color.filmSuccess
        case .archived: return Color.filmTertiary
        }
    }

    private var tabPicker: some View {
        SegmentedPicker(selection: $selectedTab, options: [("Frames", "square.grid.2x2"), ("Stats", "chart.bar")])
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            framesGrid
        } else {
            statsView
        }
    }

    private var framesGrid: some View {
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...roll.capacity, id: \.self) { num in
                    if let frame = frames.first(where: { $0.number == num }) {
                        frameCell(frame: frame)
                    } else {
                        emptyCell(number: num)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func frameCell(frame: Frame) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.filmSprocket)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("#\(frame.number)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.ultraThinMaterial)
                    )

                if let ap = frame.apertureDisplay, let sh = frame.shutterDisplay {
                    Text("\(ap) \(sh)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(.ultraThinMaterial)
                        )
                }
            }
            .padding(8)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onTapGesture {
            viewerFrame = frame
        }
    }

    private func emptyCell(number: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.filmSprocket)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )

            VStack(spacing: 4) {
                Text("\(number)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color.filmTertiary.opacity(0.3))
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.filmTertiary.opacity(0.2))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            frameSheetTarget = .new(number)
        }
    }

    private var statsView: some View {
        VStack(spacing: 20) {
            apertureChart
            shutterChart
        }
        .padding(.horizontal, 16)
    }

    private var apertureChart: some View {
        let frames = roll.frames ?? []
        let grouped = Dictionary(grouping: frames.compactMap { $0.aperture }) { $0 }
        let chartData = Dictionary(uniqueKeysWithValues: grouped.map { (Aperture(rawValue: $0.key)?.displayName ?? "f/\($0.key)", Double($0.value.count)) })

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmAccent)
                Text("Aperture Distribution")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.filmSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            if chartData.isEmpty {
                Text("No aperture data yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                BarChartWrapper(data: chartData)
                    .frame(height: 200)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 18)
    }

    private var shutterChart: some View {
        let frames = roll.frames ?? []
        let grouped = Dictionary(grouping: frames.compactMap { $0.shutterSpeed }) { $0 }
        let chartData = grouped.mapValues { Double($0.count) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundColor(Color.filmGold)
                Text("Shutter Speed Distribution")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.filmSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            if chartData.isEmpty {
                Text("No shutter data yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                BarChartWrapper(data: chartData)
                    .frame(height: 200)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 18)
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
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.filmAccent, Color.filmGold],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "pickerBg", in: animation)
                                    .shadow(color: Color.filmAccent.opacity(0.3), radius: 8, x: 0, y: 3)
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
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
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
        chart.xAxis.labelFont = .systemFont(ofSize: 10, weight: .medium)
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.labelTextColor = UIColor(Color.filmTertiary)
        chart.leftAxis.labelFont = .systemFont(ofSize: 9)
        chart.leftAxis.axisMinimum = 0
        chart.rightAxis.enabled = false
        chart.animate(yAxisDuration: 0.8, easingOption: .easeOutBack)
        chart.setScaleEnabled(false)
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
        dataSet.valueFont = .systemFont(ofSize: 10, weight: .medium)
        dataSet.drawValuesEnabled = true
        let chartData = BarChartData(dataSet: dataSet)
        uiView.xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        uiView.data = chartData
    }
}
