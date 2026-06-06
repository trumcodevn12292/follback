import SwiftUI
import SwiftData
import PhotosUI
import Photos
import Kingfisher
import UniformTypeIdentifiers

struct RollDetailView: View {
    @Bindable var roll: Roll
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Camera.name) var allCameras: [Camera]
    @ObservedObject var customLabStore = CustomLabStore.shared

    @State var viewerFrame: Frame?
    @State var frameSheetTarget: FrameSheetTarget?
    @State var appeared = false
    @State var showDeleteAlert = false
    @State var fullScreenFrame: Frame?
    @State var showPhotoPicker = false
    @State var selectedPhotos: [PhotosPickerItem] = []
    @State var toastMessage: String?
    @State var showToastFlag = false
    @State var isImporting = false
    @State var showEditDetails = false
    @State var showContactSheet = false
    @State var showCarouselCreator = false
    @State var showArGallery = false
    @State var filmDetailStock: FilmStock?
    @State var showImportOptions = false
    @State var showFileImporter = false
    @State var showDriveLinkAlert = false
    @State var driveLinkText = ""
    @State var showCamera = false
    @State var isSelectMode = false
    @State var selectedFrames: Set<UUID> = []
    @State var isUploadingToDrive = false
    @State var draggedFrame: Frame?
    @State var showLocationEditor = false
    @State var showLabPicker = false
    @State var showFilmPicker = false
    @State var showDatePicker = false
    @State var showCameraPicker = false
    @State var showFormatPicker = false
    @State var editingDate: Date = Date()
    @AppStorage("lastImportSource") var lastImportSource: String = "library"
    @ObservedObject var driveService = GoogleDriveService.shared
    @State var tabBarHidden = false
    @State var showLightMeter = false
    @State var showDevRecipe = false
    @State var showAddCameraInPicker = false
    @Environment(\.horizontalSizeClass) var hSizeClass

    var matchingFilmStock: FilmStock? {
        FilmStock.allStocks.first { stock in
            stock.displayName.lowercased() == roll.filmName.lowercased() ||
            "\(stock.brand) \(stock.name)".lowercased() == roll.filmName.lowercased()
        }
    }

    var matchingCustomFilm: CustomFilm? {
        CustomFilmStore.shared.films.first {
            $0.name.lowercased() == roll.filmName.lowercased()
        }
    }

    var hasPhotos: Bool {
        let frames = roll.frames ?? []
        return frames.contains { $0.photoAssetID != nil }
    }

    var emptySlotCount: Int {
        let frames = roll.frames ?? []
        let filled = frames.filter { $0.photoAssetID != nil }.count
        return max(0, roll.capacity - filled)
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
        .fullScreenCover(isPresented: $showArGallery) {
            ARGalleryView(roll: roll)
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
            .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.medium] : [.height(310)])
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
        .sheet(isPresented: $showFormatPicker) {
            formatPickerSheet
        }
    }
}
