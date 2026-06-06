import SwiftUI
import SwiftData
import Kingfisher
import PhotosUI

struct AddRollView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Camera.name) var cameras: [Camera]
    @StateObject private var customFilmStore = CustomFilmStore.shared
    @ObservedObject private var customLabStore = CustomLabStore.shared

    @State private var step = 0
    @State private var selectedFilmStock: FilmStock?
    @State private var selectedCustomFilm: CustomFilm?
    @State private var customFilmName = ""
    @State private var searchText = ""
    @State private var selectedCamera: Camera?
    @State private var selectedCameraModelName: String?
    @State private var capacity = 36
    @State private var isHalfFrame = false
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
    @State private var activeCover: ActiveCover?
    @State private var selectedLabName: String?
    @State private var filmCostText = ""
    @State private var devCostText = ""
    @AppStorage(Money.currencyKey) private var currencyCode = Money.defaultCode

    let isoOptions = [50, 100, 200, 400, 800, 1600, 3200]

    // A single, enum-driven presentation. Stacking several
    // .fullScreenCover/.sheet modifiers on one view makes SwiftUI rebuild the
    // presenter when a modal opens, which used to wipe the wizard's state
    // (e.g. jumping back to "Choose Film" when creating a camera).
    private enum ActiveCover: Identifiable {
        case camera
        case location
        case lab
        case filmDetail(FilmStock)
        var id: String {
            switch self {
            case .camera: return "camera"
            case .location: return "location"
            case .lab: return "lab"
            case .filmDetail(let stock): return "filmDetail-\(stock.id)"
            }
        }
    }

    // Custom Film is pushed (navigationDestination) instead of presented as a
    // second full-screen cover. Its PhotosPicker is an out-of-process modal;
    // opening it on top of two stacked covers tore down the wizard. A push
    // keeps the picker only one modal level deep.
    @State private var showCustomFilmForm = false
    @State private var showAddLabSheet = false

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

                Group {
                    if step == 0 {
                        filmSelectionStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading),
                                removal: .move(edge: .leading)
                            ))
                    } else {
                        settingsStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .trailing)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeCover) { cover in
            switch cover {
            case .camera:
                AddCameraSheet { newCamera in
                    selectedCamera = newCamera
                    selectedCameraModelName = newCamera.name
                }
            case .location:
                LocationPickerView(
                    locationName: $locationName,
                    latitude: $locationLatitude,
                    longitude: $locationLongitude
                )
            case .lab:
                addRollLabPickerSheet
            case .filmDetail(let stock):
                FilmDetailPopup(stock: stock) {
                    activeCover = nil
                }
                .background(ClearBackgroundView())
            }
        }
        .navigationDestination(isPresented: $showCustomFilmForm) {
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

            Text(LocalizedStringKey(stepTitle))
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
                        if !film.brand.isEmpty {
                            Text(film.brand)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.filmTertiary)
                            Text("·")
                                .foregroundColor(Color.filmTertiary)
                        }
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

                    if let coverUrlString = stock.githubCoverUrl,
                       let coverURL = URL(string: coverUrlString) {
                        KFImage(coverURL)
                            .downsampling(size: CGSize(width: 100, height: 100))
                            .cacheOriginalImage()
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
                .onTapGesture {
                    activeCover = .filmDetail(stock)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        AddCustomFilmSheet(isoOptions: isoOptions) { film in
            customFilmStore.add(film)
            selectedCustomFilm = film
            selectedFilmStock = nil
            iso = film.iso
            showCustomFilmForm = false
        }
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
                    // Camera selection (from your cameras)
                    HStack {
                        Text("Camera")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        if cameras.isEmpty {
                            Button {
                                activeCover = .camera
                            } label: {
                                Text("+ Add Camera")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.filmAccent)
                            }
                        } else {
                            HStack(spacing: 10) {
                                Menu {
                                    ForEach(cameras) { camera in
                                        Button {
                                            selectedCamera = camera
                                            selectedCameraModelName = camera.name
                                        } label: {
                                            if let lens = camera.lens, !lens.isEmpty {
                                                Text("\(camera.name) + \(lens)")
                                            } else {
                                                Text(camera.name)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(selectedCamera?.displayNameWithLens ?? L("Select Camera"))
                                            .font(.system(size: 15))
                                            .foregroundColor(selectedCamera != nil ? Color.filmSecondary : Color.filmTertiary)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color.filmTertiary)
                                    }
                                }

                                // Present the create-camera sheet from a plain button.
                                // Triggering a sheet from inside a Menu is unreliable and
                                // could surface the wrong screen.
                                Button {
                                    activeCover = .camera
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.filmAccent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
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

                    // Exposures / Sheets
                    HStack {
                        Text(format.isSheet ? L("Sheets") : L("Exposures"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.filmText)
                        Spacer()
                        Picker("", selection: $capacity) {
                            ForEach(format.capacityOptions, id: \.self) { opt in
                                Text("\(opt)").tag(opt)
                            }
                        }
                        .tint(Color.filmSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .onChange(of: format) { _, newFormat in
                        if !newFormat.capacityOptions.contains(capacity) {
                            capacity = newFormat.defaultCapacity
                        }
                        if !newFormat.isSheet { isHalfFrame = false }
                    }

                    if format == .mm35 {
                        settingsDivider

                        Toggle(isOn: $isHalfFrame) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Half-frame")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.filmText)
                                Text(L("%d shots", capacity * 2))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.filmTertiary)
                                    .opacity(isHalfFrame ? 1 : 0)
                            }
                        }
                        .tint(Color.filmAccent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }

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
                        activeCover = .location
                    } label: {
                        HStack {
                            Text("Location")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(locationName ?? L("Add Location"))
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

                    settingsDivider

                    // Developing Lab
                    Button {
                        activeCover = .lab
                    } label: {
                        HStack {
                            Text("Developing Lab")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Text(selectedLabName ?? L("Select Lab"))
                                .font(.system(size: 14))
                                .foregroundColor(selectedLabName != nil ? Color.filmSecondary : Color.filmTertiary)
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

                // Cost section
                Text("Cost")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    costRow(label: "Film cost", text: $filmCostText)
                    settingsDivider
                    costRow(label: "Developing cost", text: $devCostText)
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
            Text(LocalizedStringKey(label))
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

    private func costRow(label: String, text: Binding<String>) -> some View {
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
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func parsedCost(_ text: String) -> Double? {
        Money.parseAmount(text)
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

        let halfFrame = isHalfFrame && format == .mm35
        let effectiveCapacity = halfFrame ? capacity * 2 : capacity

        let roll = Roll(
            filmName: filmDisplayName,
            camera: matchedCamera,
            capacity: effectiveCapacity,
            iso: iso,
            format: format,
            evCompensation: evCompensation,
            pushPull: pushPull,
            startDate: startDate,
            notes: notes,
            locationName: locationName,
            latitude: locationLatitude,
            longitude: locationLongitude,
            labName: selectedLabName
        )
        roll.isHalfFrame = halfFrame
        roll.filmCost = parsedCost(filmCostText)
        roll.devCost = parsedCost(devCostText)
        modelContext.insert(roll)
        try? modelContext.save()
        NotificationCenter.default.post(name: .widgetDataDidChange, object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private var addRollLabPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Button {
                        showAddLabSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color.filmAccent)
                            Text("Add Lab")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.filmText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Color.filmBorder.opacity(0.2))
                        .padding(.horizontal, 16)

                    if !customLabStore.labs.isEmpty {
                        Section {
                            ForEach(customLabStore.labs) { lab in
                                Button {
                                    selectedLabName = lab.name
                                    activeCover = nil
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
                                        if selectedLabName == lab.name {
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
                                    selectedLabName = lab.name
                                    activeCover = nil
                                } label: {
                                    HStack(spacing: 12) {
                                        labAvatarView(lab)
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
                                        if selectedLabName == lab.name {
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
                    Button("Cancel") { activeCover = nil }
                        .foregroundColor(Color.filmAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddLabSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color.filmAccent)
                    }
                }
            }
            .sheet(isPresented: $showAddLabSheet) {
                LabEditSheet { newLab in
                    selectedLabName = newLab.name
                    activeCover = nil
                }
            }
        }
    }

    @ViewBuilder
    private func labAvatarView(_ lab: FilmLab) -> some View {
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
}

// Isolated custom-film creation form. Lives in its own view so its
// PhotosPicker presents from this subtree instead of stacking another modal
// onto AddRollView (which used to rebuild the wizard and kick back to
// "Choose Film").
private struct AddCustomFilmSheet: View {
    let isoOptions: [Int]
    var onSave: (CustomFilm) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var iso = 400
    @State private var type = "COLOR_NEGATIVE"
    @State private var coverItem: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var showPhotoPicker = false

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                customFilmHeader
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Cover photo
                        VStack(spacing: 8) {
                            Text("COVER PHOTO")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                showPhotoPicker = true
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.filmSurface)
                                        .frame(height: 140)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.filmBorder, lineWidth: 0.5)
                                        )

                                    if let data = coverData, let uiImage = UIImage(data: data) {
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
                        .photosPicker(isPresented: $showPhotoPicker, selection: $coverItem, matching: .images)

                        // Film name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FILM NAME")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)

                            TextField("e.g. My Kodak Portra 400", text: $name)
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

                        // Brand
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BRAND")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.filmTertiary)
                                .kerning(0.8)

                            TextField("e.g. Kodak, Fujifilm, Ilford", text: $brand)
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
                                        iso = option
                                    } label: {
                                        Text("\(option)")
                                            .font(.system(size: 13, weight: iso == option ? .bold : .medium))
                                            .foregroundColor(iso == option ? Color.filmBackground : Color.filmSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                iso == option
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
                                        type = typeCode
                                    } label: {
                                        HStack {
                                            Text(typeName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Color.filmText)
                                            Spacer()
                                            if type == typeCode {
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
                                name: name,
                                brand: brand,
                                iso: iso,
                                filmType: type,
                                coverImageData: coverData
                            )
                            onSave(film)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        } label: {
                            Text("Save Custom Film")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.filmBackground)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(name.isEmpty ? Color.filmTertiary : Color.filmAccent)
                                )
                        }
                        .disabled(name.isEmpty)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: coverItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    coverData = data
                }
            }
        }
    }

    private var customFilmHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
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

            Text("Custom Film")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.filmText)

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
