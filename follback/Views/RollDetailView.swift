import SwiftUI
import SwiftData
import PhotosUI
import Photos
import DGCharts
import Kingfisher

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
    @State private var appeared = false
    @State private var showDeleteAlert = false
    @State private var fullScreenFrame: Frame?
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var toastMessage: String?
    @State private var showToastFlag = false
    @State private var isImporting = false

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerBar
                    heroSection
                    if hasPhotos {
                        sortFilterBar
                        photoGrid
                    } else {
                        emptyStateView
                    }
                }
                .padding(.bottom, 100)
            }

            importButton

            if showToastFlag, let message = toastMessage {
                toastView(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $selectedPhotos,
                      maxSelectionCount: emptySlotCount,
                      matching: .images)
        .onChange(of: selectedPhotos) { _, newItems in
            Task { await importPhotos(newItems) }
        }
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

    private var hasPhotos: Bool {
        let frames = roll.frames ?? []
        return frames.contains { $0.photoAssetID != nil }
    }

    private var emptySlotCount: Int {
        let frames = roll.frames ?? []
        let filled = frames.filter { $0.photoAssetID != nil }.count
        return max(0, roll.capacity - filled)
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 12) {
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

            if hasPhotos {
                Button {
                    showPhotoPicker = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus")
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

    // MARK: - Hero Section (Filmer style)
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Roll title
            Text(roll.filmName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.filmText)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Film cover + info chips (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Film cover image
                    filmCoverImage

                    infoChipView(label: "Film format", value: roll.filmFormat.displayName)

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    infoChipView(label: "ISO", value: "\(roll.iso)")

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    infoChipView(label: "Exposures", value: "\(roll.filledFrames)/\(roll.capacity)")

                    if let camera = roll.camera {
                        Divider()
                            .frame(height: 40)
                            .background(Color.filmBorder)
                        infoChipView(label: "Camera", value: camera.name)
                    }

                    if roll.pushPull != 0 {
                        Divider()
                            .frame(height: 40)
                            .background(Color.filmBorder)
                        infoChipView(label: "Push/Pull", value: String(format: "%+.1f", roll.pushPull))
                    }
                }
                .padding(.horizontal, 16)
            }

            if !roll.notes.isEmpty {
                Text(roll.notes)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.filmSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    private var filmCoverImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.filmSurface)
                .frame(width: 72, height: 72)

            if let stock = matchingFilmStock,
               let coverUrlString = stock.fullCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .requestModifier(FilmerImageAuth.shared.modifier)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "film")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }
        }
    }

    private func infoChipView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.filmTertiary)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.filmText)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(Color.filmTertiary.opacity(0.5))

                Text("No photos yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.filmSecondary)

                Text("Import photos from your camera roll to fill this film roll")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.filmTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sort/Filter Bar
    private var sortFilterBar: some View {
        HStack {
            let frames = roll.frames ?? []
            let photoCount = frames.filter { $0.photoAssetID != nil }.count
            Text("\(photoCount) photos")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.filmTertiary)
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    private var statusColor: Color {
        switch roll.rollStatus {
        case .inProgress: return Color.filmAccent
        case .developed: return Color.filmSuccess
        case .archived: return Color.filmTertiary
        }
    }

    // MARK: - Import Button (bottom floating)
    private var importButton: some View {
        Button {
            if !isImporting {
                showPhotoPicker = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } label: {
            HStack(spacing: 8) {
                if isImporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.filmBackground))
                        .scaleEffect(0.8)
                    Text("Importing...")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                    Text("Import Photos")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: 220)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.filmAccent)
            )
        }
        .disabled(isImporting || emptySlotCount == 0)
        .opacity(emptySlotCount == 0 && !isImporting ? 0.5 : 1)
        .padding(.bottom, 30)
    }

    // MARK: - Toast
    private func toastView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.filmSuccess)
            VStack(alignment: .leading, spacing: 2) {
                Text("Import complete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.filmText)
                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.filmSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.filmSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.filmBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 90)
    }

    // MARK: - Photo Import
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        var importedCount = 0
        for (index, item) in items.enumerated() {
            guard index < emptySlots.count else { break }
            let slotNumber = emptySlots[index]

            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
                let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? jpegData.write(to: url)

                if let existingFrame = frames.first(where: { $0.number == slotNumber }) {
                    existingFrame.photoAssetID = filename
                } else {
                    let newFrame = Frame(number: slotNumber, photoAssetID: filename)
                    newFrame.roll = roll
                    modelContext.insert(newFrame)
                }
                importedCount += 1
            }
        }

        if importedCount > 0 {
            try? modelContext.save()
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
                toastMessage = "Imported \(importedCount) photo\(importedCount == 1 ? "" : "s")"
                withAnimation(.easeOut(duration: 0.3)) {
                    showToastFlag = true
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) {
                    showToastFlag = false
                }
            }
        } else {
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
            }
        }
    }

    // MARK: - Photo Grid (Filmer style - 3 column, edge-to-edge)
    private var photoGrid: some View {
        let frames = (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(frames, id: \.id) { frame in
                photoCell(frame: frame)
            }
        }
        .padding(.horizontal, 0)
    }

    private func photoCell(frame: Frame) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.filmSurface)
                    .aspectRatio(1, contentMode: .fill)
            }

            Text("\(frame.number)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            fullScreenFrame = frame
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        .contextMenu {
            Button {
                frameSheetTarget = .edit(frame)
            } label: {
                Label("Edit Details", systemImage: "pencil")
            }
            Button {
                fullScreenFrame = frame
            } label: {
                Label("View Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
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
