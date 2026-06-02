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
    @State private var showEditDetails = false
    @State private var showContactSheet = false

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
        .sheet(isPresented: $showEditDetails) {
            EditRollDetailsView(roll: roll)
        }
        .fullScreenCover(isPresented: $showContactSheet) {
            ContactSheetView(roll: roll)
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
                Button { showEditDetails = true } label: { Label("Edit Details", systemImage: "pencil") }
                if hasPhotos {
                    Button { showContactSheet = true } label: { Label("Contact Sheet", systemImage: "film") }
                }
                if roll.rollStatus == .inProgress || roll.rollStatus == .completed {
                    Button { markDeveloped() } label: { Label("Mark Developed", systemImage: "checkmark.seal") }
                }
                if roll.rollStatus != .inProgress {
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

            if let location = roll.locationName {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                    Text(location)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(Color.filmTertiary)
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
        case .completed: return Color.filmSuccess
        case .developed: return Color.blue
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
            roll.checkAutoComplete()
            try? modelContext.save()
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
                let completed = roll.isCompleted
                toastMessage = completed
                    ? "Roll complete! \(importedCount) photo\(importedCount == 1 ? "" : "s") imported"
                    : "Imported \(importedCount) photo\(importedCount == 1 ? "" : "s")"
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
                GeometryReader { geo in
                    photoCell(frame: frame, size: geo.size.width)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 0)
    }

    private func photoCell(frame: Frame, size: CGFloat) -> some View {
        Group {
            if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.filmSurface)
                    .frame(width: size, height: size)
            }
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
    @State private var currentIndex: Int = 0

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photoFrames.enumerated()), id: \.element.id) { index, photoFrame in
                    PhotoPageView(frame: photoFrame, onDismiss: { dismiss() })
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

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
                    if currentIndex < photoFrames.count {
                        Text("\(currentIndex + 1) / \(photoFrames.count)")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
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

                if showInfo, currentIndex < photoFrames.count {
                    infoBarFor(photoFrames[currentIndex])
                }
            }
        }
        .onAppear {
            if let idx = photoFrames.firstIndex(where: { $0.id == frame.id }) {
                currentIndex = idx
            }
        }
    }

    private func infoBarFor(_ f: Frame) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                if let ap = f.apertureDisplay {
                    infoChip(icon: "camera.aperture", value: ap)
                }
                if let sh = f.shutterDisplay {
                    infoChip(icon: "timer", value: sh)
                }
                if f.flashUsed {
                    infoChip(icon: "bolt.fill", value: "Flash")
                }
            }
            if let loc = f.locationName, !loc.isEmpty {
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

}

// MARK: - Photo Page View (single photo in album viewer)

private struct PhotoPageView: View {
    let frame: Frame
    let onDismiss: () -> Void
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .scaleEffect(scale)
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
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            } else if let assetID = frame.photoAssetID {
                PhotoThumbnail(assetID: assetID)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        guard let assetID = frame.photoAssetID else { return }

        // Local file
        if assetID.contains("_frame_") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                self.image = img
            }
            return
        }

        // PHAsset
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

// MARK: - Edit Roll Details

struct EditRollDetailsView: View {
    @Bindable var roll: Roll
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var filmName: String = ""
    @State private var iso: Int = 400
    @State private var capacity: Int = 36
    @State private var format: FilmFormat = .mm35
    @State private var evCompensation: Float = 0
    @State private var pushPull: Float = 0
    @State private var notes: String = ""
    @State private var locationName: String?
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    @State private var showFilmPicker = false
    @State private var showLocationPicker = false
    @State private var searchText = ""

    private var filteredGroups: [(brand: String, stocks: [FilmStock])]? {
        let groups = FilmStock.groupedByBrand
        if searchText.isEmpty { return groups }
        let query = searchText.lowercased()
        return groups.compactMap { group in
            let filtered = group.stocks.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.brand.lowercased().contains(query)
            }
            return filtered.isEmpty ? nil : (brand: group.brand, stocks: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Film selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FILM STOCK")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)

                        Button {
                            showFilmPicker = true
                        } label: {
                            HStack {
                                Text(filmName.isEmpty ? "Select Film" : filmName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(filmName.isEmpty ? Color.filmTertiary : Color.filmText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.filmTertiary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Basic settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BASIC SETTINGS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)

                        VStack(spacing: 0) {
                            settingsRow("ISO", value: "\(iso)") {
                                Picker("", selection: $iso) {
                                    ForEach([50, 100, 160, 200, 400, 800, 1600, 3200], id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.filmAccent)
                            }

                            Divider().background(Color.filmBorder.opacity(0.3))

                            settingsRow("Format", value: format.displayName) {
                                Picker("", selection: $format) {
                                    ForEach(FilmFormat.allCases, id: \.self) { f in
                                        Text(f.displayName).tag(f)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.filmAccent)
                            }

                            Divider().background(Color.filmBorder.opacity(0.3))

                            settingsRow("Exposures", value: "\(capacity)") {
                                Picker("", selection: $capacity) {
                                    Text("12").tag(12)
                                    Text("24").tag(24)
                                    Text("36").tag(36)
                                }
                                .pickerStyle(.menu)
                                .tint(Color.filmAccent)
                            }

                            Divider().background(Color.filmBorder.opacity(0.3))

                            HStack {
                                Text("EV Compensation")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.filmText)
                                Spacer()
                                Text(String(format: "%+.1f", evCompensation))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.filmAccent)
                                Stepper("", value: $evCompensation, in: -3...3, step: 0.5)
                                    .labelsHidden()
                            }
                            .padding(16)

                            Divider().background(Color.filmBorder.opacity(0.3))

                            HStack {
                                Text("Push/Pull")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.filmText)
                                Spacer()
                                Text(String(format: "%+.1f", pushPull))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.filmAccent)
                                Stepper("", value: $pushPull, in: -3...3, step: 0.5)
                                    .labelsHidden()
                            }
                            .padding(16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.filmSurface)
                        )
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LOCATION")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)

                        Button {
                            showLocationPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.filmAccent)
                                Text((locationName ?? "").isEmpty ? "Add Location" : (locationName ?? ""))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor((locationName ?? "").isEmpty ? Color.filmTertiary : Color.filmText)
                                    .lineLimit(1)
                                Spacer()
                                if !(locationName ?? "").isEmpty {
                                    Button {
                                        locationName = nil
                                        locationLatitude = nil
                                        locationLongitude = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.filmTertiary)
                                    }
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.filmTertiary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)

                        TextEditor(text: $notes)
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmText)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                            )
                    }

                    // Save button
                    Button {
                        saveChanges()
                    } label: {
                        Text("Save Changes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmAccent)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.filmAccent)
                }
            }
            .sheet(isPresented: $showFilmPicker) {
                filmPickerSheet
            }
            .fullScreenCover(isPresented: $showLocationPicker) {
                LocationPickerView(
                    locationName: $locationName,
                    latitude: $locationLatitude,
                    longitude: $locationLongitude
                )
            }
        }
        .onAppear {
            filmName = roll.filmName
            iso = roll.iso
            capacity = roll.capacity
            format = roll.filmFormat
            evCompensation = roll.evCompensation
            pushPull = roll.pushPull
            notes = roll.notes
            locationName = roll.locationName
            locationLatitude = roll.latitude
            locationLongitude = roll.longitude
        }
    }

    private func settingsRow<Content: View>(_ label: String, value: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.filmText)
            Spacer()
            trailing()
        }
        .padding(16)
    }

    private var filmPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(filteredGroups ?? [], id: \.brand) { group in
                        Section {
                            ForEach(group.stocks, id: \.id) { stock in
                                Button {
                                    filmName = stock.displayName
                                    iso = stock.isoValue
                                    showFilmPicker = false
                                } label: {
                                    HStack(spacing: 12) {
                                        if let coverUrl = stock.fullCoverUrl,
                                           let url = URL(string: coverUrl) {
                                            KFImage(url)
                                                .requestModifier(FilmerImageAuth.shared.modifier)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 44, height: 44)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        Text(stock.displayName)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Color.filmText)
                                        Spacer()
                                        if filmName == stock.displayName {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Color.filmAccent)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.filmBorder.opacity(0.2))
                                    .padding(.horizontal, 16)
                            }
                        } header: {
                            Text(group.brand)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.filmText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.filmBackground)
                        }
                    }
                }
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Choose Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showFilmPicker = false }
                        .foregroundColor(Color.filmAccent)
                }
            }
            .searchable(text: $searchText, prompt: "Search films...")
        }
    }

    private func saveChanges() {
        roll.filmName = filmName
        roll.iso = iso
        roll.capacity = capacity
        roll.format = format.rawValue
        roll.evCompensation = evCompensation
        roll.pushPull = pushPull
        roll.notes = notes
        roll.locationName = (locationName ?? "").isEmpty ? nil : locationName
        roll.latitude = locationLatitude
        roll.longitude = locationLongitude
        roll.updatedAt = Date()
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Contact Sheet Aspect Ratio

enum ContactSheetRatio: String, CaseIterable, Identifiable {
    case square = "1:1"
    case portrait = "4:5"
    case story = "9:16"
    case landscape = "16:9"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .square: return "Instagram"
        case .portrait: return "Portrait"
        case .story: return "Story"
        case .landscape: return "Landscape"
        }
    }

    var icon: String {
        switch self {
        case .square: return "square"
        case .portrait: return "rectangle.portrait"
        case .story: return "rectangle.portrait"
        case .landscape: return "rectangle"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        case .landscape: return 16.0 / 9.0
        }
    }

    var exportSize: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1350)
        case .story: return CGSize(width: 1080, height: 1920)
        case .landscape: return CGSize(width: 1920, height: 1080)
        }
    }

    var columns: Int {
        switch self {
        case .square: return 4
        case .portrait: return 3
        case .story: return 2
        case .landscape: return 5
        }
    }
}

// MARK: - Contact Sheet View

struct ContactSheetView: View {
    let roll: Roll
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var isLoading = true
    @State private var savedToPhotos = false
    @State private var isSaving = false
    @State private var selectedRatio: ContactSheetRatio = .square

    private let filmBase = Color(hex: "#1C1408")
    private let rebateText = Color(hex: "#C86B28")
    private let paperBg = Color(hex: "#F5F0E8")
    private let inkColor = Color(hex: "#2A2218")

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0908").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("CONTACT SHEET")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .kerning(2)
                    }
                    Spacer()
                    Button { saveContactSheet() } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(savedToPhotos ? .green : .white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                    }
                    .disabled(isSaving || isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                // Aspect ratio picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ContactSheetRatio.allCases) { ratio in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedRatio = ratio
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: ratio.icon)
                                        .font(.system(size: 11))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(ratio.rawValue)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        Text(ratio.label)
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                }
                                .foregroundColor(selectedRatio == ratio ? Color(hex: "#0A0908") : .white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedRatio == ratio ? Color.filmAccent : Color.white.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)

                // Preview
                ScrollView(showsIndicators: false) {
                    contactSheetPreview
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }

            // Toast
            if savedToPhotos {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        Text("Saved to Photos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: "#2A2A2A")))
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { loadAllImages() }
    }

    // MARK: - Preview
    private var contactSheetPreview: some View {
        let cols = selectedRatio.columns
        let rows = stride(from: 0, to: photoFrames.count, by: cols).map {
            Array(photoFrames[$0..<min($0 + cols, photoFrames.count)])
        }

        return VStack(spacing: 0) {
            // Title area
            VStack(spacing: 6) {
                Text(roll.filmName.uppercased())
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(inkColor)
                    .kerning(2)

                HStack(spacing: 8) {
                    if let camera = roll.camera {
                        chipLabel(camera.name)
                    }
                    chipLabel("ISO \(roll.iso)")
                    chipLabel(roll.format)
                }

                Text(roll.startDate.formatted(.dateTime.month(.wide).day().year()).uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#9A8E7E"))
                    .kerning(1)
            }
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Film strips
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                filmStripRow(row: row, cols: cols)
                    .padding(.vertical, 2)
            }

            // Footer
            HStack(spacing: 0) {
                Text("FILMVAULT")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#C8BAA8"))
                    .kerning(3)
                Spacer()
                Text("\(photoFrames.count) EXPOSURES")
                    .font(.system(size: 6, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#C8BAA8"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 6)
        .background(paperBg)
    }

    private func chipLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 7, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "#6A5E4E"))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(hex: "#C8BAA8"), lineWidth: 0.5)
            )
    }

    // MARK: - Film Strip Row
    private func filmStripRow(row: [Frame], cols: Int) -> some View {
        VStack(spacing: 0) {
            sprocketRail(count: cols * 2)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    rebateTop(frame: frame)
                        .frame(maxWidth: .infinity)
                }
                if row.count < cols {
                    ForEach(0..<(cols - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 10)
                    }
                }
            }
            .frame(height: 12)
            .background(filmBase)

            HStack(spacing: 1) {
                ForEach(row, id: \.id) { frame in
                    ZStack {
                        Color(hex: "#0D0A06")
                        if let img = loadedImages[frame.number] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .aspectRatio(3.0/2.0, contentMode: .fit)
                    .clipped()
                }
                if row.count < cols {
                    ForEach(0..<(cols - row.count), id: \.self) { _ in
                        Color(hex: "#0D0A06")
                            .aspectRatio(3.0/2.0, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 3)
            .background(filmBase)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    rebateBottom(frame: frame)
                        .frame(maxWidth: .infinity)
                }
                if row.count < cols {
                    ForEach(0..<(cols - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 10)
                    }
                }
            }
            .frame(height: 12)
            .background(filmBase)

            sprocketRail(count: cols * 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5))
    }

    private func rebateTop(frame: Frame) -> some View {
        HStack(spacing: 0) {
            Text("\(frame.number)")
                .font(.system(size: 5, weight: .bold, design: .monospaced))
                .foregroundColor(rebateText.opacity(0.7))
            Spacer()
            Text("\(frame.number)A")
                .font(.system(size: 4, weight: .medium, design: .monospaced))
                .foregroundColor(rebateText.opacity(0.35))
        }
        .padding(.horizontal, 3)
    }

    private func rebateBottom(frame: Frame) -> some View {
        HStack(spacing: 0) {
            Text("◀ \(frame.number)")
                .font(.system(size: 4, weight: .medium, design: .monospaced))
                .foregroundColor(rebateText.opacity(0.4))
            Spacer()
        }
        .padding(.horizontal, 3)
    }

    private func sprocketRail(count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                Spacer()
                RoundedRectangle(cornerRadius: 0.4)
                    .fill(paperBg)
                    .frame(width: 3.5, height: 2)
                Spacer()
            }
        }
        .frame(height: 5)
        .background(filmBase)
    }

    // MARK: - Load Images
    private func loadAllImages() {
        let frames = photoFrames

        Task {
            for frame in frames {
                guard let assetID = frame.photoAssetID else { continue }

                if assetID.contains("_frame_") {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent(assetID)
                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                        await MainActor.run { loadedImages[frame.number] = img }
                    }
                    continue
                }

                let results = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
                guard let asset = results.firstObject else { continue }

                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = false
                options.resizeMode = .fast

                let targetSize = CGSize(width: 400, height: 400)
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                    if let image = image {
                        DispatchQueue.main.async {
                            loadedImages[frame.number] = image
                        }
                    }
                }
            }
            await MainActor.run { isLoading = false }
        }
    }

    // MARK: - Save
    @MainActor
    private func saveContactSheet() {
        isSaving = true
        let renderer = ImageRenderer(content: exportImage)
        renderer.scale = 3.0

        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4)) {
                savedToPhotos = true
                isSaving = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { savedToPhotos = false }
            }
        } else {
            isSaving = false
        }
    }

    // MARK: - Export Image
    @MainActor
    private var exportImage: some View {
        let cols = selectedRatio.columns
        let rows = stride(from: 0, to: photoFrames.count, by: cols).map {
            Array(photoFrames[$0..<min($0 + cols, photoFrames.count)])
        }
        let size = selectedRatio.exportSize

        return VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Header
            VStack(spacing: 8) {
                Text(roll.filmName.uppercased())
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(inkColor)
                    .kerning(3)

                HStack(spacing: 12) {
                    if let camera = roll.camera {
                        exportChip(camera.name)
                    }
                    exportChip("ISO \(roll.iso)")
                    exportChip(roll.format)
                }

                Text(roll.startDate.formatted(.dateTime.month(.wide).day().year()).uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#9A8E7E"))
                    .kerning(1.5)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Film strips
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                exportFilmStrip(row: row, cols: cols)
                    .padding(.vertical, 3)
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Text("FILMVAULT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(Color(hex: "#C8BAA8"))
                    .kerning(4)
                Spacer()
                Text("\(photoFrames.count) EXPOSURES · \(selectedRatio.rawValue)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#C8BAA8"))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 12)
        .frame(width: size.width / 3, height: size.height / 3)
        .background(paperBg)
    }

    private func exportChip(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "#6A5E4E"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(hex: "#C8BAA8"), lineWidth: 0.5)
            )
    }

    @MainActor
    private func exportFilmStrip(row: [Frame], cols: Int) -> some View {
        VStack(spacing: 0) {
            exportSprocketRail(count: cols * 3)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    HStack {
                        Text("\(frame.number)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.7))
                        Spacer()
                        Text("\(frame.number)A")
                            .font(.system(size: 5, weight: .medium, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.4))
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                }
                if row.count < cols {
                    ForEach(0..<(cols - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 14)
            .background(filmBase)

            HStack(spacing: 1.5) {
                ForEach(row, id: \.id) { frame in
                    ZStack {
                        Color(hex: "#0D0A06")
                        if let img = loadedImages[frame.number] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .aspectRatio(3.0/2.0, contentMode: .fit)
                    .clipped()
                }
                if row.count < cols {
                    ForEach(0..<(cols - row.count), id: \.self) { _ in
                        Color(hex: "#0D0A06")
                            .aspectRatio(3.0/2.0, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 4)
            .background(filmBase)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    HStack {
                        Text("◀ \(frame.number)")
                            .font(.system(size: 5, weight: .medium, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                }
                if row.count < cols {
                    ForEach(0..<(cols - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 14)
            .background(filmBase)

            exportSprocketRail(count: cols * 3)
        }
    }

    private func exportSprocketRail(count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                Spacer()
                RoundedRectangle(cornerRadius: 0.6)
                    .fill(paperBg)
                    .frame(width: 5, height: 3)
                Spacer()
            }
        }
        .frame(height: 7)
        .background(filmBase)
    }
}
