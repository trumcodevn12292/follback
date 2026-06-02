import SwiftUI
import SwiftData
import PhotosUI
import Photos
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
    @State private var fullScreenFrame: Frame?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerBar
                heroCard
                tabPicker
                tabContent
            }
            .padding(.bottom, 20)
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
        .fullScreenCover(item: $fullScreenFrame) { frame in
            FullScreenPhotoView(frame: frame, roll: roll)
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

    // MARK: - Header
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

    // MARK: - Hero
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

            // Film strip progress
            filmStripProgress

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

    private var filmStripProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track with sprocket holes
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

    // MARK: - Tabs
    private var tabPicker: some View {
        SegmentedPicker(selection: $selectedTab, options: [("Frames", "square.grid.2x2"), ("Stats", "chart.bar")])
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            photoGrid
        } else {
            statsView
        }
    }

    // MARK: - Photo Grid (iOS Photos style)
    private var photoGrid: some View {
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]

        return VStack(spacing: 2) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(1...roll.capacity, id: \.self) { num in
                    if let frame = frames.first(where: { $0.number == num }) {
                        filledPhotoCell(frame: frame)
                    } else {
                        emptyPhotoCell(number: num)
                    }
                }
            }
        }
        .padding(.horizontal, 2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 14)
    }

    private func filledPhotoCell(frame: Frame) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.filmSurface)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(Color.filmTertiary.opacity(0.5))
                            Text("#\(frame.number)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.filmTertiary.opacity(0.4))
                        }
                    )
            }

            // Frame number overlay
            Text("\(frame.number)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.5))
                )
                .padding(4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if frame.photoAssetID != nil {
                fullScreenFrame = frame
            } else {
                viewerFrame = frame
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        .contextMenu {
            Button {
                frameSheetTarget = .edit(frame)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            if frame.photoAssetID != nil {
                Button {
                    fullScreenFrame = frame
                } label: {
                    Label("View Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            }
        }
    }

    private func emptyPhotoCell(number: Int) -> some View {
        Rectangle()
            .fill(Color.filmSprocket)
            .aspectRatio(1, contentMode: .fill)
            .overlay(
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color.filmAccent.opacity(0.08))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.filmAccent.opacity(0.5))
                    }
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.filmTertiary.opacity(0.3))
                }
            )
            .overlay(
                Rectangle()
                    .stroke(Color.filmBorder.opacity(0.3), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                frameSheetTarget = .new(number)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }

    // MARK: - Stats
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

// MARK: - Full Screen Photo View (iOS Photos style)
struct FullScreenPhotoView: View {
    let frame: Frame
    let roll: Roll
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showInfo = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3)) {
                                    if scale < 1.0 { scale = 1.0 }
                                    if scale > 5.0 { scale = 5.0 }
                                    lastScale = scale
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                } else if value.translation.height > 50 {
                                    dismiss()
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showInfo.toggle()
                        }
                    }
            } else if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No photo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Top bar
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Text("Frame #\(frame.number)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation { showInfo.toggle() }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if showInfo {
                    infoBar
                }
            }
        }
        .onAppear { loadImage() }
    }

    private var infoBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let ap = frame.apertureDisplay {
                    infoChip(icon: "camera.aperture", value: ap)
                }
                if let sh = frame.shutterDisplay {
                    infoChip(icon: "timer", value: sh)
                }
                if frame.flashUsed {
                    infoChip(icon: "bolt.fill", value: "Flash")
                }
            }
            if let loc = frame.locationName, !loc.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(loc)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(.white.opacity(0.9))
    }

    private func loadImage() {
        guard let assetID = frame.photoAssetID else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return }
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { img, _ in
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}

// MARK: - Segmented Picker
struct SegmentedPicker: View {
    @Binding var selection: Int
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<options.count, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
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
                    .foregroundColor(selection == index ? Color.filmBackground : Color.filmTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selection == index ? Color.filmAccent : Color.clear)
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
                        .stroke(Color.filmBorder.opacity(0.4), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Chart Wrappers
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
