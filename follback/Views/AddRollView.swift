import SwiftUI
import SwiftData
import Kingfisher
import PhotosUI

struct AddRollView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Camera.name) var cameras: [Camera]
    @StateObject private var customFilmStore = CustomFilmStore.shared

    @State private var step = 0
    @State private var selectedFilmStock: FilmStock?
    @State private var selectedCustomFilm: CustomFilm?
    @State private var customFilmName = ""
    @State private var searchText = ""
    @State private var selectedCamera: Camera?
    @State private var selectedCameraModelName: String?
    @State private var capacity = 36
    @State private var iso = 400
    @State private var format: FilmFormat = .mm35
    @State private var evCompensation: Float = 0
    @State private var pushPull: Float = 0
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var locationName: String?
    @State private var locationLatitude: Double?
    @State private var locationLongitude: Double?
    @State private var appeared = false
    @State private var showCustomInput = false
    @State private var showCameraPicker = false
    @State private var showLocationPicker = false

    // Custom film creation states
    @State private var showCustomFilmForm = false
    @State private var newCustomName = ""
    @State private var newCustomISO = 400
    @State private var newCustomType = "COLOR_NEGATIVE"
    @State private var newCustomCoverItem: PhotosPickerItem?
    @State private var newCustomCoverData: Data?

    let isoOptions = [50, 100, 200, 400, 800, 1600, 3200]

    private var filteredStocks: [(brand: String, stocks: [FilmStock])] {
        if searchText.isEmpty {
            return FilmStock.groupedByBrandPopularFirst
        }
        let query = searchText.lowercased()
        return FilmStock.groupedByBrandPopularFirst.compactMap { group in
            let filtered = group.stocks.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.brand.lowercased().contains(query) ||
                "\($0.isoValue)".contains(query)
            }
            return filtered.isEmpty ? nil : (brand: group.brand, stocks: filtered)
        }
    }

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                progressIndicator

                TabView(selection: $step) {
                    filmSelectionStep.tag(0)
                    settingsStep.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPickerView(selectedCameraName: $selectedCameraModelName)
        }
        .fullScreenCover(isPresented: $showLocationPicker) {
            LocationPickerView(
                locationName: $locationName,
                latitude: $locationLatitude,
                longitude: $locationLongitude
            )
        }
        .fullScreenCover(isPresented: $showCustomFilmForm) {
            customFilmFormSheet
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Button {
                if step > 0 {
                    withAnimation(.spring(response: 0.35)) { step -= 1 }
                } else {
                    dismiss()
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: step > 0 ? "chevron.left" : "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.filmText)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.filmSurface)
                            .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                    )
            }

            Spacer()

            Text(stepTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.filmText)

            Spacer()

            if step == 0 && canAdvance {
                Button {
                    withAnimation(.spring(response: 0.35)) { step += 1 }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("Next")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.filmBackground)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.filmAccent)
                        )
                }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Choose Film"
        case 1: return "Confirm"
        default: return ""
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return selectedFilmStock != nil || selectedCustomFilm != nil || !customFilmName.isEmpty
        case 1: return true
        default: return false
        }
    }

    // MARK: - Progress
    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<2) { i in
                Capsule()
                    .fill(i <= step ? Color.filmAccent : Color.filmBorder.opacity(0.4))
                    .frame(height: 3)
                    .animation(.spring(response: 0.4), value: step)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Step 1: Film Selection
    private var filmSelectionStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmTertiary)
                    TextField("Search film stocks...", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmText)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)

                // Custom film button → opens form sheet
                Button {
                    showCustomFilmForm = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.filmAccent.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.filmAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Custom Film")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.filmText)
                            Text("Add your own film stock")
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.filmSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.filmBorder, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // My Custom Films section
                if !customFilmStore.films.isEmpty && searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("MY CUSTOM FILMS")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.filmSecondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            Spacer()
                            Text("\(customFilmStore.films.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.filmTertiary)
                        }
                        .padding(.horizontal, 20)

                        ForEach(customFilmStore.films) { film in
                            customFilmRow(film)
                        }
                    }
                }

                // Film stock list
                LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                    ForEach(filteredStocks, id: \.brand) { group in
                        Section {
                            ForEach(group.stocks) { stock in
                                filmStockRow(stock)
                            }
                        } header: {
                            HStack {
                                Text(group.brand)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.filmSecondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                Spacer()
                                Text("\(group.stocks.count)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.filmTertiary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.filmBackground)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.top, 8)
        }
    }

    private func customFilmRow(_ film: CustomFilm) -> some View {
        let isSelected = selectedCustomFilm?.id == film.id
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCustomFilm = film
                selectedFilmStock = nil
                customFilmName = ""
                iso = film.iso
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.filmAccent.opacity(0.1))
                        .frame(width: 50, height: 50)

                    if let data = film.coverImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: 18))
                            .foregroundColor(Color.filmAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(film.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.filmText)
                    HStack(spacing: 6) {
                        Text("ISO \(film.iso)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.filmAccent)
                        Text("·")
                            .foregroundColor(Color.filmTertiary)
                        Text(film.typeDisplayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.filmTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.filmAccent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.filmAccent.opacity(0.06) : Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.filmAccent.opacity(0.3) : Color.filmBorder, lineWidth: isSelected ? 1 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .contextMenu {
            Button(role: .destructive) {
                customFilmStore.remove(film)
                if selectedCustomFilm?.id == film.id {
                    selectedCustomFilm = nil
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func filmStockRow(_ stock: FilmStock) -> some View {
        let isSelected = selectedFilmStock?.id == stock.id
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedFilmStock = stock
                selectedCustomFilm = nil
                showCustomInput = false
                customFilmName = ""
                iso = stock.isoValue
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [stock.color.opacity(0.3), stock.accentColor.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(stock.color.opacity(0.3), lineWidth: 0.5)
                        )

                    if let coverUrlString = stock.fullCoverUrl,
                       let coverURL = URL(string: coverUrlString) {
                        KFImage(coverURL)
                            .requestModifier(FilmerImageAuth.shared.modifier)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        VStack(spacing: 2) {
                            Circle()
                                .fill(stock.color)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .fill(Color.filmBackground.opacity(0.5))
                                        .frame(width: 5, height: 5)
                                )
                            RoundedRectangle(cornerRadius: 1)
                                .fill(stock.accentColor.opacity(0.6))
                                .frame(width: 20, height: 3)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(stock.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.filmText)
                    HStack(spacing: 6) {
                        Text("ISO \(stock.isoValue)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(stock.color)
                        Text("·")
                            .foregroundColor(Color.filmTertiary)
                        Text(stock.type.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.filmTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.filmAccent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.filmAccent.opacity(0.06) : Color.filmSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.filmAccent.opacity(0.3) : Color.filmBorder, lineWidth: isSelected ? 1 : 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Custom Film Form Sheet
    private var customFilmFormSheet: some View {
        NavigationStack {
            ZStack {
                Color.filmBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Cover photo
                        VStack(spacing: 8) {
                            Text("COVER PHOTO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            PhotosPicker(selection: $newCustomCoverItem, matching: .images) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.filmSurface)
                                        .frame(height: 140)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.filmBorder, lineWidth: 0.5)
                                        )

                                    if let data = newCustomCoverData, let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    } else {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 28, weight: .light))
                                                .foregroundColor(Color.filmTertiary)
                                            Text("Tap to add cover")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.filmTertiary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        // Film name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FILM NAME")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)

                            TextField("e.g. My Kodak Portra 400", text: $newCustomName)
                                .font(.system(size: 16))
                                .foregroundColor(Color.filmText)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.filmSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.filmBorder, lineWidth: 0.5)
                                        )
                                )
                        }

                        // ISO
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ISO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)

                            HStack(spacing: 0) {
                                ForEach(isoOptions, id: \.self) { option in
                                    Button {
                                        newCustomISO = option
                                    } label: {
                                        Text("\(option)")
                                            .font(.system(size: 13, weight: newCustomISO == option ? .bold : .medium))
                                            .foregroundColor(newCustomISO == option ? Color.filmBackground : Color.filmSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                newCustomISO == option
                                                    ? AnyView(Capsule().fill(Color.filmAccent))
                                                    : AnyView(Capsule().fill(Color.clear))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                            )
                        }

                        // Film type
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FILM TYPE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)

                            VStack(spacing: 0) {
                                ForEach(Array(zip(CustomFilm.filmTypes, CustomFilm.filmTypeNames)), id: \.0) { typeCode, typeName in
                                    Button {
                                        newCustomType = typeCode
                                    } label: {
                                        HStack {
                                            Text(typeName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            Spacer()
                                            if newCustomType == typeCode {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Color.filmAccent)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                    }
                                    .buttonStyle(.plain)

                                    if typeCode != CustomFilm.filmTypes.last {
                                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                            )
                        }

                        // Save button
                        Button {
                            let film = CustomFilm(
                                id: UUID().uuidString,
                                name: newCustomName,
                                iso: newCustomISO,
                                filmType: newCustomType,
                                coverImageData: newCustomCoverData
                            )
                            customFilmStore.add(film)
                            selectedCustomFilm = film
                            selectedFilmStock = nil
                            iso = film.iso
                            showCustomFilmForm = false
                            resetCustomForm()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Text("Save Custom Film")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.filmBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(newCustomName.isEmpty ? Color.filmTertiary : Color.filmAccent)
                                )
                        }
                        .disabled(newCustomName.isEmpty)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Custom Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showCustomFilmForm = false
                        resetCustomForm()
                    }
                    .foregroundColor(Color.filmAccent)
                }
            }
            .onChange(of: newCustomCoverItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        newCustomCoverData = data
                    }
                }
            }
        }
    }

    private func resetCustomForm() {
        newCustomName = ""
        newCustomISO = 400
        newCustomType = "COLOR_NEGATIVE"
        newCustomCoverItem = nil
        newCustomCoverData = nil
    }

    // MARK: - Step 2: Settings
    private var settingsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Basic Info")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    // Camera Model
                    Button {
                        showCameraPicker = true
                    } label: {
                        HStack {
                            Text("Camera Model")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(selectedCameraModelName ?? "None")
                                .font(.system(size: 16))
                                .foregroundColor(Color.filmSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    settingsDivider

                    // Film
                    settingsRow(label: "Film", value: filmDisplayName)
                    settingsDivider

                    // Format
                    HStack {
                        Text("Format")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        Picker("", selection: $format) {
                            ForEach(FilmFormat.allCases, id: \.self) { f in
                                Text(f.displayName).tag(f)
                            }
                        }
                        .tint(Color.filmSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    settingsDivider

                    // Exposures
                    HStack {
                        Text("Exposures")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        Picker("", selection: $capacity) {
                            Text("12").tag(12)
                            Text("24").tag(24)
                            Text("36").tag(36)
                        }
                        .tint(Color.filmSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    if selectedFilmStock == nil && selectedCustomFilm == nil {
                        settingsDivider

                        HStack {
                            Text("ISO")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Picker("", selection: $iso) {
                                ForEach(isoOptions, id: \.self) { option in
                                    Text("\(option)").tag(option)
                                }
                            }
                            .tint(Color.filmSecondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )

                // Shot Info section
                Text("Shot Info")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    // Start Date
                    HStack {
                        Text("Start Date")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Color.filmAccent)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    settingsDivider

                    // EV Compensation
                    VStack(spacing: 10) {
                        HStack {
                            Text("EV Compensation")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(String(format: "%+.1f", evCompensation))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.filmAccent)
                        }
                        Slider(value: $evCompensation, in: -3...3, step: 0.5)
                            .tint(Color.filmAccent)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    settingsDivider

                    // Push/Pull
                    VStack(spacing: 10) {
                        HStack {
                            Text("Push/Pull")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(String(format: "%+.1f", pushPull))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.filmGold)
                        }
                        Slider(value: $pushPull, in: -3...3, step: 0.5)
                            .tint(Color.filmGold)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    settingsDivider

                    // Location
                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack {
                            Text("Location")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(locationName ?? "Add Location")
                                .font(.system(size: 14))
                                .foregroundColor(locationName != nil ? Color.filmSecondary : Color.filmTertiary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.filmSurface)
                )

                // Notes section
                Text("Notes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .padding(.horizontal, 4)

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

                // Confirm button
                Button {
                    saveRoll()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("Confirm")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.filmText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.filmSurface)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.filmText)
            Spacer()
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(Color.filmSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var settingsDivider: some View {
        Divider()
            .background(Color.filmBorder.opacity(0.3))
            .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    private var filmDisplayName: String {
        if let stock = selectedFilmStock {
            return stock.displayName
        } else if let custom = selectedCustomFilm {
            return custom.name
        }
        return customFilmName
    }

    // MARK: - Save
    private func saveRoll() {
        let matchedCamera = selectedCameraModelName.flatMap { name in
            cameras.first { $0.name == name || name.contains($0.name) }
        } ?? selectedCamera

        let roll = Roll(
            filmName: filmDisplayName,
            camera: matchedCamera,
            capacity: capacity,
            iso: iso,
            format: format,
            evCompensation: evCompensation,
            pushPull: pushPull,
            startDate: startDate,
            notes: notes,
            locationName: locationName,
            latitude: locationLatitude,
            longitude: locationLongitude
        )
        modelContext.insert(roll)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
