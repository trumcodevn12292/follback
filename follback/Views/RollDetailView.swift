import SwiftUI
import SwiftData
import PhotosUI
import Photos
import Kingfisher
import UniformTypeIdentifiers

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
    @Query(sort: \Camera.name) private var allCameras: [Camera]
    @ObservedObject private var customLabStore = CustomLabStore.shared

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
    @State private var showCarouselCreator = false
    @State private var filmDetailStock: FilmStock?
    @State private var showImportOptions = false
    @State private var showFileImporter = false
    @State private var showDriveLinkAlert = false
    @State private var driveLinkText = ""
    @State private var showCamera = false
    @State private var isSelectMode = false
    @State private var selectedFrames: Set<UUID> = []
    @State private var isUploadingToDrive = false
    @State private var draggedFrame: Frame?
    @State private var showLocationEditor = false
    @State private var showLabPicker = false
    @State private var showFilmPicker = false
    @State private var showDatePicker = false
    @State private var showCameraPicker = false
    @State private var editingDate: Date = Date()
    @AppStorage("lastImportSource") private var lastImportSource: String = "library"
    @ObservedObject private var driveService = GoogleDriveService.shared
    @State private var tabBarHidden = false
    @State private var showLightMeter = false
    @State private var showDevRecipe = false

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private var matchingCustomFilm: CustomFilm? {
        CustomFilmStore.shared.films.first {
            $0.name.lowercased() == roll.filmName.lowercased()
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
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .global)
                .onEnded { value in
                    let startX = value.startLocation.x
                    if startX < 40 && value.translation.width > 60 && abs(value.translation.height) < 100 {
                        withAnimation(.easeOut(duration: 0.25)) {
                            dismiss()
                        }
                    }
                }
        )
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(tabBarHidden ? .hidden : .visible, for: .tabBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) { tabBarHidden = true }
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.3)) { tabBarHidden = false }
        }
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
        .fullScreenCover(isPresented: $showLightMeter) {
            LightMeterView(filmISO: roll.iso)
        }
        .alert("Delete Roll?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(roll)
                try? modelContext.save()
                NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \"\(roll.filmName)\" and all its frames.")
        }
        .sheet(isPresented: $showEditDetails) {
            EditRollDetailsView(roll: roll)
        }
        .sheet(isPresented: $showDevRecipe) {
            DevRecipeEditorView(roll: roll)
        }
        .fullScreenCover(isPresented: $showContactSheet) {
            ContactSheetView(roll: roll)
        }
        .fullScreenCover(isPresented: $showCarouselCreator) {
            SeamlessCarouselView(roll: roll)
        }
        .fullScreenCover(item: $filmDetailStock) { stock in
            FilmDetailPopup(stock: stock) {
                filmDetailStock = nil
            }
            .background(ClearBackgroundView())
        }
        .sheet(isPresented: $showImportOptions) {
            ImportSourceSheet(
                onPhotos: {
                    lastImportSource = "library"
                    showImportOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showPhotoPicker = true }
                },
                onCamera: {
                    lastImportSource = "camera"
                    showImportOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCamera = true }
                },
                onFiles: {
                    lastImportSource = "files"
                    showImportOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showFileImporter = true }
                },
                onDriveLink: {
                    lastImportSource = "drive"
                    showImportOptions = false
                    if driveService.isSignedIn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            driveLinkText = ""
                            showDriveLinkAlert = true
                        }
                    } else {
                        Task { await driveService.signIn() }
                    }
                },
                slotsAvailable: emptySlotCount
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerWrapper { image in
                Task { await importCameraPhoto(image) }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            Task { await importFromFiles(result) }
        }
        .alert("Google Drive Link", isPresented: $showDriveLinkAlert) {
            TextField("Paste Drive folder or file link", text: $driveLinkText)
            Button("Cancel", role: .cancel) { }
            Button("Import") {
                Task { await importFromDriveLink(driveLinkText) }
            }
        } message: {
            Text("Paste a Google Drive folder or file link to download and import photos.")
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $showLocationEditor) {
            LocationPickerView(
                locationName: Binding(
                    get: { roll.locationName },
                    set: { roll.locationName = $0 }
                ),
                latitude: Binding(
                    get: { roll.latitude },
                    set: { roll.latitude = $0 }
                ),
                longitude: Binding(
                    get: { roll.longitude },
                    set: { roll.longitude = $0 }
                )
            )
        }
        .fullScreenCover(isPresented: $showLabPicker) {
            labPickerSheet
        }
        .fullScreenCover(isPresented: $showFilmPicker) {
            filmPickerSheet
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showCameraPicker) {
            cameraPickerSheet
        }
    }

    private var formattedShootingDate: String {
        let formatter = DateFormatter()
        formatter.locale = appLocale()
        formatter.setLocalizedDateFormatFromTemplate("ddMMyy")
        return formatter.string(from: roll.startDate)
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.25)) {
                    dismiss()
                }
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
                    showImportOptions = true
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
                Button { showLightMeter = true } label: { Label("Light Meter", systemImage: "camera.metering.spot") }
                if hasPhotos {
                    Button { showContactSheet = true } label: { Label("Contact Sheet", systemImage: "film") }
                    Button { showCarouselCreator = true } label: { Label("Create Post", systemImage: "square.grid.3x1.below.line.grid.1x2") }
                    Button {
                        withAnimation(.spring(response: 0.3)) { isSelectMode = true }
                    } label: { Label("Select Photos", systemImage: "checkmark.circle") }
                }
                if let driveLink = roll.driveFolderLink, !driveLink.isEmpty {
                    Button {
                        UIPasteboard.general.string = driveLink
                        Task { await showToast("Drive link copied") }
                    } label: { Label("Copy Drive Link", systemImage: "doc.on.doc") }
                }
                if roll.rollStatus == .inProgress || roll.rollStatus == .completed {
                    Button { markDeveloped() } label: { Label("Mark Developed", systemImage: "checkmark.seal") }
                }
                if roll.rollStatus != .inProgress {
                    Button { markInProgress() } label: { Label("Mark Active", systemImage: "play") }
                }
                Button { archiveRoll() } label: { Label("Archive", systemImage: "archivebox") }
                if isSelectMode && !selectedFrames.isEmpty {
                    Button(role: .destructive) { deleteSelectedPhotos() } label: { Label("Delete Selected (\(selectedFrames.count))", systemImage: "trash") }
                } else {
                    Button(role: .destructive) { showDeleteAlert = true } label: { Label("Delete Roll", systemImage: "trash") }
                }
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
                    // Film cover image (long-press to change film)
                    filmCoverImage
                        .contextMenu {
                            Button {
                                showFilmPicker = true
                            } label: {
                                Label("Change Film Stock", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }

                    infoChipView(
                        label: "Film format",
                        value: roll.isHalfFrame
                            ? "\(roll.filmFormat.displayName) · \(L("Half"))"
                            : roll.filmFormat.displayName
                    )

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    infoChipView(label: "ISO", value: "\(roll.iso)")

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    // Date shooting next to ISO
                    Button {
                        editingDate = roll.startDate
                        showDatePicker = true
                    } label: {
                        infoChipView(label: "Date", value: formattedShootingDate)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)

                    infoChipView(label: "Photos", value: "\(roll.filledFrames)/\(roll.capacity)")

                    Divider()
                        .frame(height: 40)
                        .background(Color.filmBorder)
                    Button {
                        showCameraPicker = true
                    } label: {
                        infoChipView(label: "Camera", value: roll.camera?.name ?? L("Add"))
                    }
                    .buttonStyle(.plain)

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
                Button {
                    showLocationEditor = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text(location)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .foregroundColor(Color.filmTertiary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            if let lab = roll.labName {
                Button {
                    showLabPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 12))
                        Text(lab)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.5)
                    }
                    .foregroundColor(Color.filmTertiary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }

            if !roll.notes.isEmpty {
                Text(roll.notes)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.filmSecondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            developmentCard
                .padding(.horizontal, 16)

            costCard
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    private var costCard: some View {
        Button {
            showEditDetails = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmAccent)
                    Text("COST")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)
                    Spacer()
                    Image(systemName: roll.hasCost ? "pencil" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.filmTertiary)
                }

                if roll.hasCost {
                    VStack(alignment: .leading, spacing: 6) {
                        if let film = roll.filmCost {
                            costLine(label: L("Film cost"), value: Money.format(film))
                        }
                        if let dev = roll.devCost {
                            costLine(label: L("Developing cost"), value: Money.format(dev))
                        }
                        if let total = roll.totalCost {
                            Divider().background(Color.filmBorder.opacity(0.3))
                            costLine(label: L("Total cost"), value: Money.format(total), emphasized: true)
                        }
                    }
                } else {
                    Text("Track what you spent on film and developing.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func costLine(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: emphasized ? .semibold : .regular))
                .foregroundColor(emphasized ? Color.filmText : Color.filmSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: emphasized ? .bold : .medium))
                .foregroundColor(emphasized ? Color.filmAccent : Color.filmText)
        }
    }

    private var developmentCard: some View {
        Button {
            showDevRecipe = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmAccent)
                    Text("DEVELOPMENT")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.filmTertiary)
                        .kerning(0.8)
                    Spacer()
                    Image(systemName: roll.hasDevRecipe ? "pencil" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.filmTertiary)
                }

                if roll.hasDevRecipe {
                    VStack(alignment: .leading, spacing: 6) {
                        if let dev = roll.devDeveloper, !dev.isEmpty {
                            devLine(icon: "flask.fill",
                                    text: [dev, roll.devDilution].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  "))
                        }
                        if !devTempTimeText.isEmpty {
                            devLine(icon: "thermometer.medium", text: devTempTimeText)
                        }
                        if roll.pushPull != 0 {
                            devLine(icon: "arrow.up.arrow.down",
                                    text: "\(roll.pushPull > 0 ? L("Push") : L("Pull")) \(String(format: "%+d", Int(roll.pushPull))) \(abs(roll.pushPull) == 1 ? L("stop") : L("stops"))")
                        }
                        if let agit = roll.devAgitation, !agit.isEmpty {
                            devLine(icon: "hand.draw", text: agit)
                        }
                        if let date = roll.developedDate {
                            devLine(icon: "calendar", text: L("Developed %@", date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(appLocale()))))
                        }
                        if let notes = roll.devNotes, !notes.isEmpty {
                            devLine(icon: "text.alignleft", text: notes)
                        }
                    }
                } else {
                    Text("Log your developer, dilution, temperature, time and push/pull.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var devTempTimeText: String {
        var parts: [String] = []
        if let t = roll.devTempC { parts.append(String(format: "%.1f °C", t)) }
        if let s = roll.devTimeSeconds { parts.append(DevRecipePresets.timeLabel(s)) }
        return parts.joined(separator: "  ·  ")
    }

    private func devLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.filmAccent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var filmCoverImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.filmSurface)
                .frame(width: 72, height: 72)

            if let custom = matchingCustomFilm,
               let data = custom.coverImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let stock = matchingFilmStock,
               let coverUrlString = stock.githubCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .downsampling(size: CGSize(width: 144, height: 144))
                    .cacheOriginalImage()
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
        .onTapGesture {
            if let stock = matchingFilmStock {
                filmDetailStock = stock
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showFilmPicker = true
        }
    }

    private func infoChipView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(LocalizedStringKey(label))
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
            Text(L(roll.rollStatus.displayName))
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
            if isSelectMode && driveService.isSignedIn && !selectedFrames.isEmpty {
                let frames = (roll.frames ?? []).filter { $0.photoAssetID != nil }.sorted { $0.number < $1.number }
                Task { await uploadSelectedToDrive(frames: frames) }
            } else if !isImporting && !isSelectMode {
                showImportOptions = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } label: {
            HStack(spacing: 8) {
                if isImporting || isUploadingToDrive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.filmBackground))
                        .scaleEffect(0.8)
                    Text(isUploadingToDrive ? "Uploading..." : "Importing...")
                        .font(.system(size: 16, weight: .semibold))
                } else if isSelectMode && driveService.isSignedIn && !selectedFrames.isEmpty {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                    Text("Upload to Drive")
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
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelectMode)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedFrames.count)
        }
        .disabled(isImporting || isUploadingToDrive || (emptySlotCount == 0 && !isSelectMode))
        .opacity((emptySlotCount == 0 && !isImporting && !isSelectMode) ? 0.5 : 1)
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

    // MARK: - Photo Import (from Photo Library)
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        var importedCount = 0
        let importMode = UserDefaults.standard.string(forKey: "photoImportMode") ?? "Copy"
        let shouldUploadToDrive = driveService.isSignedIn

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

                if importMode == "Reference" {
                    saveToPhotoAlbum(data: jpegData)
                }

                if shouldUploadToDrive {
                    Task { await driveService.uploadPhoto(data: jpegData, filename: "FilmVault/\(roll.filmName)/frame_\(slotNumber).jpg") }
                }

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

        await finishImport(count: importedCount)
    }

    // MARK: - Import from Files

    private func importFromFiles(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result, !urls.isEmpty else { return }

        let imageURLs = urls.filter { url in
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "webp"].contains(ext)
        }

        guard !imageURLs.isEmpty else {
            await showToast("No images found in selection")
            return
        }

        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        guard !emptySlots.isEmpty else {
            await showToast("No empty slots available")
            return
        }

        var importedCount = 0
        let importMode = UserDefaults.standard.string(forKey: "photoImportMode") ?? "Copy"
        let shouldUploadToDrive = driveService.isSignedIn

        for (index, url) in imageURLs.enumerated() {
            guard index < emptySlots.count else { break }
            let slotNumber = emptySlots[index]

            autoreleasepool {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                guard let data = try? Data(contentsOf: url),
                      let uiImage = UIImage(data: data),
                      let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }

                let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
                let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? jpegData.write(to: destURL)

                if importMode == "Reference" {
                    saveToPhotoAlbum(data: jpegData)
                }

                if shouldUploadToDrive {
                    Task { await driveService.uploadPhoto(data: jpegData, filename: "FilmVault/\(roll.filmName)/frame_\(slotNumber).jpg") }
                }

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

        await finishImport(count: importedCount)
    }

    // MARK: - Import from Google Drive Link

    private func importFromDriveLink(_ link: String) async {
        guard !link.isEmpty else { return }
        await MainActor.run { isImporting = true }

        let downloaded = await driveService.downloadFromLink(link)
        guard !downloaded.isEmpty else {
            await showToast("No images found at link")
            return
        }

        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }

        var importedCount = 0
        let shouldUploadToDrive = driveService.isSignedIn

        for (index, file) in downloaded.enumerated() {
            guard index < emptySlots.count else { break }
            let slotNumber = emptySlots[index]

            autoreleasepool {
                guard let uiImage = UIImage(data: file.data),
                      let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }

                let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
                let destURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? jpegData.write(to: destURL)

                if shouldUploadToDrive {
                    Task { await driveService.uploadPhoto(data: jpegData, filename: "FilmVault/\(roll.filmName)/frame_\(slotNumber).jpg") }
                }

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

        await finishImport(count: importedCount)
    }

    // MARK: - Helpers

    private func saveToPhotoAlbum(data: Data) {
        // No longer duplicating photos — Reference mode now links directly
        // This function is kept for backward compatibility but is a no-op
    }

    private func finishImport(count: Int) async {
        if count > 0 {
            roll.checkAutoComplete()
            try? modelContext.save()
            NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
                let completed = roll.isCompleted
                toastMessage = completed
                    ? "Roll complete! \(count) photo\(count == 1 ? "" : "s") imported"
                    : "Imported \(count) photo\(count == 1 ? "" : "s")"
                withAnimation(.easeOut(duration: 0.3)) { showToastFlag = true }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.3)) { showToastFlag = false }
            }
        } else {
            await MainActor.run {
                isImporting = false
                selectedPhotos = []
            }
        }
    }

    private func showToast(_ message: String) async {
        await MainActor.run {
            isImporting = false
            toastMessage = message
            withAnimation(.easeOut(duration: 0.3)) { showToastFlag = true }
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await MainActor.run {
            withAnimation(.easeIn(duration: 0.3)) { showToastFlag = false }
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

        return VStack(spacing: 0) {
            if isSelectMode {
                selectModeBar(frames: frames)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(frames, id: \.id) { frame in
                    GeometryReader { geo in
                        photoCell(frame: frame, size: geo.size.width)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .onDrag {
                        draggedFrame = frame
                        return NSItemProvider(object: frame.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: PhotoDropDelegate(
                        frame: frame,
                        roll: roll,
                        draggedFrame: $draggedFrame,
                        modelContext: modelContext
                    ))
                }
            }
            .padding(.horizontal, 0)
        }
    }

    private func selectModeBar(frames: [Frame]) -> some View {
        HStack(spacing: 12) {
            Button("Select All") {
                selectedFrames = Set(frames.map { $0.id })
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.filmAccent)

            Spacer()

            Text("\(selectedFrames.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.filmTertiary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    isSelectMode = false
                    selectedFrames.removeAll()
                }
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.filmAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.filmSurface)
    }

    private func photoCell(frame: Frame, size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
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

            if isSelectMode {
                ZStack {
                    Circle()
                        .fill(selectedFrames.contains(frame.id) ? Color.filmAccent : Color.black.opacity(0.4))
                        .frame(width: 24, height: 24)
                    if selectedFrames.contains(frame.id) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .padding(6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectMode {
                if selectedFrames.contains(frame.id) {
                    selectedFrames.remove(frame.id)
                } else {
                    selectedFrames.insert(frame.id)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                fullScreenFrame = frame
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
        .contextMenu {
            Button {
                fullScreenFrame = frame
            } label: {
                Label("View Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isSelectMode = true
                    selectedFrames.insert(frame.id)
                }
            } label: {
                Label("Select", systemImage: "checkmark.circle")
            }
        }
    }

    private func markDeveloped() {
        roll.updateStatus(.developed)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
    }

    private func markInProgress() {
        roll.updateStatus(.inProgress)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
    }

    private func archiveRoll() {
        roll.updateStatus(.archived)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        dismiss()
    }

    private func deleteSelectedPhotos() {
        let frames = roll.frames ?? []
        let toDelete = frames.filter { selectedFrames.contains($0.id) }
        for frame in toDelete {
            if let assetID = frame.photoAssetID {
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docsDir.appendingPathComponent(assetID)
                try? FileManager.default.removeItem(at: fileURL)
            }
            modelContext.delete(frame)
        }
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        withAnimation(.spring(response: 0.3)) {
            isSelectMode = false
            selectedFrames.removeAll()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Lab Picker Sheet
    private var labPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !customLabStore.labs.isEmpty {
                        Section {
                            ForEach(customLabStore.labs) { lab in
                                Button {
                                    roll.labName = lab.name
                                    try? modelContext.save()
                                    showLabPicker = false
                                } label: {
                                    HStack(spacing: 12) {
                                        CustomLabAvatar(lab: lab, size: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lab.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            if !lab.labDescription.isEmpty {
                                                Text(lab.labDescription)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.filmTertiary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                        if roll.labName == lab.name {
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
                            Text("MY LABS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.filmText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.filmBackground)
                        }
                    }
                    ForEach(FilmLab.groupedByCity, id: \.city) { group in
                        Section {
                            ForEach(group.labs) { lab in
                                Button {
                                    roll.labName = lab.name
                                    try? modelContext.save()
                                    showLabPicker = false
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lab.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            Text(lab.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.filmTertiary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        if roll.labName == lab.name {
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
                            Text(group.city)
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
            .navigationTitle("Change Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLabPicker = false }
                }
            }
        }
    }

    // MARK: - Film Picker Sheet
    private var filmPickerSheet: some View {
        NavigationStack {
            FilmStockPickerView(selectedFilmName: Binding(
                get: { roll.filmName },
                set: { newName in
                    roll.filmName = newName
                    if let stock = FilmStock.allStocks.first(where: {
                        $0.displayName.lowercased() == newName.lowercased() ||
                        "\($0.brand) \($0.name)".lowercased() == newName.lowercased()
                    }) {
                        roll.iso = stock.isoValue
                    }
                    roll.updatedAt = Date()
                    try? modelContext.save()
                    NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
                    showFilmPicker = false
                }
            ))
            .navigationTitle("Change Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showFilmPicker = false }
                }
            }
        }
    }

    // MARK: - Camera Picker Sheet
    private var cameraPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Button {
                        roll.camera = nil
                        roll.updatedAt = Date()
                        try? modelContext.save()
                        showCameraPicker = false
                    } label: {
                        HStack {
                            Text("No Camera")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            if roll.camera == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.filmAccent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Color.filmBorder.opacity(0.2))
                        .padding(.horizontal, 16)

                    if allCameras.isEmpty {
                        Text("No cameras yet. Add cameras from the Cameras tab.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(allCameras) { camera in
                            Button {
                                roll.camera = camera
                                roll.updatedAt = Date()
                                try? modelContext.save()
                                showCameraPicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(camera.displayNameWithLens)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Color.filmText)
                                        Text(camera.brand)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.filmTertiary)
                                    }
                                    Spacer()
                                    if roll.camera?.id == camera.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.filmAccent)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.filmBorder.opacity(0.2))
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Change Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCameraPicker = false }
                }
            }
        }
    }

    // MARK: - Date Picker Sheet
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Shooting Date", selection: $editingDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.filmAccent)
                    .padding()

                Button {
                    roll.startDate = editingDate
                    try? modelContext.save()
                    showDatePicker = false
                } label: {
                    Text("Save")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.filmBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.filmAccent))
                }
                .padding(.horizontal, 20)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Edit Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Upload to Google Drive

    private func uploadSelectedToDrive(frames: [Frame]) async {
        guard driveService.isSignedIn, !selectedFrames.isEmpty else { return }
        await MainActor.run { isUploadingToDrive = true }

        let folderName = roll.filmName
        let folderId = await driveService.createFolder(name: folderName)

        let framesToUpload = frames.filter { selectedFrames.contains($0.id) }
        var uploadedCount = 0

        for frame in framesToUpload {
            guard let assetID = frame.photoAssetID else { continue }
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docsDir.appendingPathComponent(assetID)
            guard let data = try? Data(contentsOf: fileURL) else { continue }

            let filename = "frame_\(frame.number).jpg"
            _ = await driveService.uploadPhoto(data: data, filename: filename, folderId: folderId)
            uploadedCount += 1
        }

        if let folderId = folderId {
            let driveLink = "https://drive.google.com/drive/folders/\(folderId)"
            await MainActor.run {
                roll.driveFolderLink = driveLink
                try? modelContext.save()
                NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
            }
        }

        await MainActor.run {
            isUploadingToDrive = false
            isSelectMode = false
            selectedFrames.removeAll()
        }
        await showToast("Uploaded \(uploadedCount) photo\(uploadedCount == 1 ? "" : "s") to Drive")
    }

    // MARK: - Camera Import

    private func importCameraPhoto(_ image: UIImage) async {
        await MainActor.run { isImporting = true }
        let frames = (roll.frames ?? []).sorted { $0.number < $1.number }
        let emptySlots = (1...roll.capacity).filter { num in
            !frames.contains { $0.number == num && $0.photoAssetID != nil }
        }
        guard let slotNumber = emptySlots.first else {
            await showToast("No empty slots available")
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.9) else { return }
        let filename = "\(roll.id.uuidString)_frame_\(slotNumber).jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? jpegData.write(to: url)

        let importMode = UserDefaults.standard.string(forKey: "photoImportMode") ?? "Copy"
        if importMode == "Reference" {
            saveToPhotoAlbum(data: jpegData)
        }

        if let existingFrame = frames.first(where: { $0.number == slotNumber }) {
            existingFrame.photoAssetID = filename
        } else {
            let newFrame = Frame(number: slotNumber, photoAssetID: filename)
            newFrame.roll = roll
            modelContext.insert(newFrame)
        }

        await finishImport(count: 1)
    }
}

// MARK: - Import Source Sheet

struct ImportSourceSheet: View {
    let onPhotos: () -> Void
    let onCamera: () -> Void
    let onFiles: () -> Void
    let onDriveLink: () -> Void
    let slotsAvailable: Int

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("Import Photos")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.filmText)
                .padding(.top, 16)

            Text("\(slotsAvailable) slot\(slotsAvailable == 1 ? "" : "s") available")
                .font(.system(size: 13))
                .foregroundColor(Color.filmTertiary)
                .padding(.top, 4)

            HStack(spacing: 24) {
                importSourceButton(icon: "photo.on.rectangle", title: "Ảnh", color: .green) {
                    onPhotos()
                }
                importSourceButton(icon: "camera.fill", title: "Camera", color: .orange) {
                    onCamera()
                }
            }
            .padding(.top, 20)

            HStack(spacing: 12) {
                importActionButton(icon: "folder.fill", title: "Files") {
                    onFiles()
                }
                importActionButton(icon: "link", title: "Google Drive Link") {
                    onDriveLink()
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.filmBackground)
    }

    private func importSourceButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.filmText)
            }
        }
    }

    private func importActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.filmAccent)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.filmText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.filmTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Camera Picker Wrapper

struct CameraPickerWrapper: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - Photo Drop Delegate

struct PhotoDropDelegate: DropDelegate {
    let frame: Frame
    let roll: Roll
    @Binding var draggedFrame: Frame?
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        draggedFrame = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedFrame, dragged.id != frame.id else { return }
        let frames = (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
        guard let fromIndex = frames.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = frames.firstIndex(where: { $0.id == frame.id }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let numbers = frames.map { $0.number }
            var reordered = frames
            let moving = reordered.remove(at: fromIndex)
            reordered.insert(moving, at: toIndex)
            for (i, f) in reordered.enumerated() {
                f.number = numbers[i]
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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

    @State private var currentImage: UIImage?
    @State private var shareImage: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photoFrames.enumerated()), id: \.element.id) { index, photoFrame in
                    PhotoPageView(frame: photoFrame, onDismiss: { dismiss() }, loadedImage: $currentImage)
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

                    Button {
                        shareCurrentPhoto()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
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
        .background(ShareController(image: shareImage, onComplete: { shareImage = nil }))
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
                    infoChip(icon: "bolt.fill", value: L("Flash"))
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

    private func shareCurrentPhoto() {
        guard let img = currentImage else { return }
        let card = PhotoShareCardView(image: img, frame: photoFrames[currentIndex], roll: roll)
        let renderer = ImageRenderer(content: card)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        renderer.scale = 1
        shareImage = renderer.uiImage
    }
}

// MARK: - ShareController
private struct ShareController: UIViewControllerRepresentable {
    let image: UIImage?
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let image else { return }
        let avc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        avc.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        uiViewController.present(avc, animated: true)
    }
}

// MARK: - Photo Page View (single photo in album viewer)

private struct PhotoPageView: View {
    let frame: Frame
    let onDismiss: () -> Void
    @Binding var loadedImage: UIImage?
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
        .onDisappear { image = nil }
        .onChange(of: image) { _, new in loadedImage = new }
    }

    private func loadImage() {
        guard image == nil, let assetID = frame.photoAssetID else { return }

        let screenScale = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width * screenScale
        let screenHeight = UIScreen.main.bounds.height * screenScale
        let maxDimension = max(screenWidth, screenHeight)

        // Local file
        if !assetID.contains("/") {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(assetID)
            DispatchQueue.global(qos: .userInitiated).async {
                guard let img = downsampledImage(at: url, maxPixel: maxDimension) else { return }
                DispatchQueue.main.async { self.image = img }
            }
            return
        }

        // PHAsset — request screen-sized, not maximum
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = result.firstObject else { return }
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: maxDimension, height: maxDimension)
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { img, _ in
            DispatchQueue.main.async {
                self.image = img
            }
        }
    }
}

// MARK: - Chart Wrappers
// MARK: - Edit Roll Details

struct EditRollDetailsView: View {
    @Bindable var roll: Roll
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var customLabStore = CustomLabStore.shared

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
    @State private var labName: String?
    @State private var filmCostText: String = ""
    @State private var devCostText: String = ""
    @AppStorage(Money.currencyKey) private var currencyCode = Money.defaultCode
    @State private var showFilmPicker = false
    @State private var showLocationPicker = false
    @State private var showLabPicker = false
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
                                    if roll.isHalfFrame {
                                        Text("24").tag(24)
                                        Text("48").tag(48)
                                        Text("72").tag(72)
                                    } else {
                                        Text("12").tag(12)
                                        Text("24").tag(24)
                                        Text("36").tag(36)
                                    }
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
                                Text((locationName ?? "").isEmpty ? L("Add Location") : (locationName ?? ""))
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

                    // Lab
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DEVELOPING LAB")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)

                        Button {
                            showLabPicker = true
                        } label: {
                            HStack(spacing: 10) {
                                if let name = labName, !name.isEmpty {
                                    if let customLab = customLabStore.lab(named: name) {
                                        CustomLabAvatar(lab: customLab, size: 28)
                                    } else if let lab = FilmLab.allLabs.first(where: { $0.name == name }) {
                                        labAvatar(lab)
                                    }
                                    Text(name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color.filmText)
                                        .lineLimit(1)
                                } else {
                                    Image(systemName: "flask.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.filmAccent)
                                    Text("Select Lab")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color.filmTertiary)
                                }
                                Spacer()
                                if !(labName ?? "").isEmpty {
                                    Button {
                                        labName = nil
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

                    // Cost
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COST")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                            .kerning(0.8)

                        VStack(spacing: 0) {
                            editCostRow(label: "Film cost", text: $filmCostText)
                            Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)
                            editCostRow(label: "Developing cost", text: $devCostText)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.filmSurface)
                        )
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
            .fullScreenCover(isPresented: $showLabPicker) {
                labPickerSheet
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
            labName = roll.labName
            filmCostText = roll.filmCost.map { formattedCostInput($0) } ?? ""
            devCostText = roll.devCost.map { formattedCostInput($0) } ?? ""
        }
    }

    private func editCostRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.filmText)
            Spacer()
            Text(Money.symbol(for: currencyCode))
                .font(.system(size: 15))
                .foregroundColor(Color.filmTertiary)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.filmText)
                .frame(maxWidth: 110)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let formatted = Money.groupedInput(newValue)
                    if formatted != newValue { text.wrappedValue = formatted }
                }
        }
        .padding(16)
    }

    /// Renders a stored amount as grouped input text without trailing ".0".
    private func formattedCostInput(_ value: Double) -> String {
        Money.editableText(value)
    }

    private func parsedCost(_ text: String) -> Double? {
        Money.parseAmount(text)
    }

    private func settingsRow<Content: View>(_ label: String, value: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Text(LocalizedStringKey(label))
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
                                        if let coverUrl = stock.githubCoverUrl,
                                           let url = URL(string: coverUrl) {
                                            KFImage(url)
                                                .downsampling(size: CGSize(width: 88, height: 88))
                                                .cacheOriginalImage()
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

    private var labPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if !customLabStore.labs.isEmpty {
                        Section {
                            ForEach(customLabStore.labs) { lab in
                                Button {
                                    labName = lab.name
                                    showLabPicker = false
                                } label: {
                                    HStack(spacing: 12) {
                                        CustomLabAvatar(lab: lab, size: 36)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lab.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            if !lab.labDescription.isEmpty {
                                                Text(lab.labDescription)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.filmTertiary)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                        if labName == lab.name {
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
                            Text("MY LABS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.filmText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.filmBackground)
                        }
                    }
                    ForEach(FilmLab.groupedByCity, id: \.city) { group in
                        Section {
                            ForEach(group.labs) { lab in
                                Button {
                                    labName = lab.name
                                    showLabPicker = false
                                } label: {
                                    HStack(spacing: 12) {
                                        labAvatar(lab)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lab.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            Text(lab.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.filmTertiary)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                        if labName == lab.name {
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
                            Text(group.city)
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
            .navigationTitle("Developing Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showLabPicker = false }
                        .foregroundColor(Color.filmAccent)
                }
            }
        }
    }

    @ViewBuilder
    private func labAvatar(_ lab: FilmLab) -> some View {
        if let logoUrlString = lab.logoUrl, let url = URL(string: logoUrlString) {
            KFImage(url)
                .downsampling(size: CGSize(width: 72, height: 72))
                .cacheOriginalImage()
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        } else {
            let initial = String(lab.name.prefix(1))
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            let hash = abs(lab.name.hashValue) % colors.count
            Text(initial)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(colors[hash]))
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
        roll.labName = (labName ?? "").isEmpty ? nil : labName
        roll.filmCost = parsedCost(filmCostText)
        roll.devCost = parsedCost(devCostText)
        roll.updatedAt = Date()
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
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
    @State private var coverImage: UIImage?

    private let columns = 4
    private let filmBase = Color(hex: "#1C1408")
    private let rebateText = Color(hex: "#C86B28")
    private let paperBg = Color(hex: "#F5F0E8")
    private let inkColor = Color(hex: "#2A2218")

    private var photoFrames: [Frame] {
        (roll.frames ?? [])
            .filter { $0.photoAssetID != nil }
            .sorted { $0.number < $1.number }
    }

    private var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    private var matchingLab: FilmLab? {
        guard let labName = roll.labName else { return nil }
        return FilmLab.allLabs.first { $0.name == labName }
    }

    private var matchingCustomLab: CustomLab? {
        guard let labName = roll.labName else { return nil }
        return CustomLabStore.shared.lab(named: labName)
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0908").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    Spacer()
                    Text("CONTACT SHEET")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .kerning(2)
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
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    contactSheetContent(fontSize: 1.0)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }

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
        .onAppear {
            loadAllImages()
            loadCoverImage()
        }
    }

    // MARK: - Shared Content
    private func contactSheetContent(fontSize: CGFloat) -> some View {
        let rows = stride(from: 0, to: photoFrames.count, by: columns).map {
            Array(photoFrames[$0..<min($0 + columns, photoFrames.count)])
        }

        return VStack(spacing: 0) {
            // Header with film cover + info
            HStack(spacing: 10 * fontSize) {
                // Film cover
                if let cover = coverImage {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44 * fontSize, height: 44 * fontSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6 * fontSize, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 6 * fontSize, style: .continuous)
                        .fill(Color(hex: "#DDD5C8"))
                        .frame(width: 44 * fontSize, height: 44 * fontSize)
                        .overlay(
                            Image(systemName: "film")
                                .font(.system(size: 16 * fontSize, weight: .light))
                                .foregroundColor(Color(hex: "#9A8E7E"))
                        )
                }

                VStack(alignment: .leading, spacing: 3 * fontSize) {
                    Text(roll.filmName.uppercased())
                        .font(.system(size: 12 * fontSize, weight: .black, design: .monospaced))
                        .foregroundColor(inkColor)
                        .kerning(1 * fontSize)
                        .lineLimit(1)

                    HStack(spacing: 6 * fontSize) {
                        if let camera = roll.camera {
                            Text(camera.name.uppercased())
                                .font(.system(size: 6 * fontSize, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "#6A5E4E"))
                                .lineLimit(1)
                        }
                        Text("ISO \(roll.iso)")
                            .font(.system(size: 6 * fontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#6A5E4E"))
                        Text(roll.format.uppercased())
                            .font(.system(size: 6 * fontSize, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#6A5E4E"))
                    }

                    Text(roll.startDate.formatted(.dateTime.month(.wide).day().year().locale(appLocale())).uppercased())
                        .font(.system(size: 6 * fontSize, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#9A8E7E"))

                    if let loc = roll.locationName, !loc.isEmpty {
                        HStack(spacing: 2 * fontSize) {
                            Image(systemName: "mappin")
                                .font(.system(size: 5 * fontSize))
                            Text(loc.uppercased())
                                .font(.system(size: 6 * fontSize, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(hex: "#9A8E7E"))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12 * fontSize)
            .padding(.top, 14 * fontSize)
            .padding(.bottom, 10 * fontSize)

            // Divider
            Rectangle()
                .fill(Color(hex: "#D5CCBE"))
                .frame(height: 0.5 * fontSize)
                .padding(.horizontal, 12 * fontSize)

            // Film strips
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                filmStripRow(row: row, scale: fontSize)
                    .padding(.vertical, 2 * fontSize)
            }

            // Footer with lab info
            HStack(spacing: 0) {
                // Lab info (left)
                if let lab = matchingLab {
                    HStack(spacing: 4 * fontSize) {
                        if let logoUrl = lab.logoUrl, let url = URL(string: logoUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                labInitialCircle(lab: lab, fontSize: fontSize)
                            }
                            .frame(width: 14 * fontSize, height: 14 * fontSize)
                            .clipShape(Circle())
                        } else {
                            labInitialCircle(lab: lab, fontSize: fontSize)
                        }
                        Text(lab.name.uppercased())
                            .font(.system(size: 5 * fontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#9A8E7E"))
                            .lineLimit(1)
                    }
                } else if let custom = matchingCustomLab {
                    HStack(spacing: 4 * fontSize) {
                        CustomLabAvatar(lab: custom, size: 14 * fontSize)
                        Text(custom.name.uppercased())
                            .font(.system(size: 5 * fontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#9A8E7E"))
                            .lineLimit(1)
                    }
                } else {
                    Text("FILMVAULT")
                        .font(.system(size: 6 * fontSize, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#C8BAA8"))
                        .kerning(3 * fontSize)
                }

                Spacer()

                Text(L("%d EXPOSURES", photoFrames.count))
                    .font(.system(size: 6 * fontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#C8BAA8"))
            }
            .padding(.horizontal, 12 * fontSize)
            .padding(.vertical, 10 * fontSize)
        }
        .padding(.horizontal, 6 * fontSize)
        .background(paperBg)
    }

    private func labInitialCircle(lab: FilmLab, fontSize: CGFloat) -> some View {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        let hash = abs(lab.name.hashValue) % colors.count
        return Text(String(lab.name.prefix(1)))
            .font(.system(size: 7 * fontSize, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 14 * fontSize, height: 14 * fontSize)
            .background(Circle().fill(colors[hash]))
    }

    private func loadCoverImage() {
        guard let stock = matchingFilmStock,
              let coverUrlString = stock.githubCoverUrl,
              let url = URL(string: coverUrlString) else { return }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let img = UIImage(data: data) else { return }
            await MainActor.run { coverImage = img }
        }
    }

    // MARK: - Film Strip Row
    private func filmStripRow(row: [Frame], scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            sprocketRail(count: columns * 2, scale: scale)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    HStack(spacing: 0) {
                        Text("\(frame.number)")
                            .font(.system(size: 5 * scale, weight: .bold, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.7))
                        Spacer()
                        Text("\(frame.number)A")
                            .font(.system(size: 4 * scale, weight: .medium, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.35))
                    }
                    .padding(.horizontal, 3 * scale)
                    .frame(maxWidth: .infinity)
                }
                if row.count < columns {
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 10 * scale)
                    }
                }
            }
            .frame(height: 12 * scale)
            .background(filmBase)

            HStack(spacing: 1 * scale) {
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
                if row.count < columns {
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color(hex: "#0D0A06")
                            .aspectRatio(3.0/2.0, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 3 * scale)
            .background(filmBase)

            HStack(spacing: 0) {
                ForEach(Array(row.enumerated()), id: \.element.id) { _, frame in
                    HStack(spacing: 0) {
                        Text("◀ \(frame.number)")
                            .font(.system(size: 4 * scale, weight: .medium, design: .monospaced))
                            .foregroundColor(rebateText.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 3 * scale)
                    .frame(maxWidth: .infinity)
                }
                if row.count < columns {
                    ForEach(0..<(columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 10 * scale)
                    }
                }
            }
            .frame(height: 12 * scale)
            .background(filmBase)

            sprocketRail(count: columns * 2, scale: scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 1.5 * scale))
    }

    private func sprocketRail(count: Int, scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                Spacer()
                RoundedRectangle(cornerRadius: 0.4 * scale)
                    .fill(paperBg)
                    .frame(width: 3.5 * scale, height: 2 * scale)
                Spacer()
            }
        }
        .frame(height: 5 * scale)
        .background(filmBase)
    }

    // MARK: - Load Images
    private func loadAllImages() {
        let frames = photoFrames

        Task.detached(priority: .userInitiated) {
            for frame in frames {
                guard let assetID = frame.photoAssetID else { continue }

                if !assetID.contains("/") {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent(assetID)
                    let img = autoreleasepool {
                        downsampledImage(at: url, maxPixel: 600)
                    }
                    if let img {
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

                let targetSize = CGSize(width: 600, height: 600)
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

        let exportView = contactSheetContent(fontSize: 2.0)
            .frame(width: 540)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0

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
}
