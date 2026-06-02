import SwiftUI
import SwiftData
import Kingfisher

struct AddRollView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Camera.name) var cameras: [Camera]

    @State private var step = 0
    @State private var selectedFilmStock: FilmStock?
    @State private var customFilmName = ""
    @State private var searchText = ""
    @State private var selectedCamera: Camera?
    @State private var capacity = 36
    @State private var iso = 400
    @State private var format: FilmFormat = .mm35
    @State private var evCompensation: Float = 0
    @State private var pushPull: Float = 0
    @State private var startDate = Date()
    @State private var notes = ""
    @State private var appeared = false
    @State private var showCustomInput = false

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
                .font(.system(size: 17, weight: .bold, design: .serif))
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
                                .fill(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
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
        case 0: return selectedFilmStock != nil || !customFilmName.isEmpty
        case 1: return true
        default: return false
        }
    }

    // MARK: - Progress
    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<2) { i in
                Capsule()
                    .fill(i <= step
                          ? LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing)
                          : LinearGradient(colors: [Color.filmBorder, Color.filmBorder], startPoint: .leading, endPoint: .trailing)
                    )
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
                        .font(.system(size: 16))
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

                // Custom name option
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showCustomInput.toggle()
                        if showCustomInput {
                            selectedFilmStock = nil
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.filmAccent.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "pencil.line")
                                .font(.system(size: 18))
                                .foregroundColor(Color.filmAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Film Name")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.filmText)
                            Text("Enter your own film stock name")
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary)
                        }
                        Spacer()
                        Image(systemName: showCustomInput ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.filmTertiary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.filmSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(showCustomInput ? Color.filmAccent.opacity(0.3) : Color.filmBorder, lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                if showCustomInput {
                    TextField("e.g. Kodak Portra 400", text: $customFilmName)
                        .font(.system(size: 16))
                        .foregroundColor(Color.filmText)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.filmSurfaceSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.filmAccent.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .padding(.horizontal, 16)
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

    private func filmStockRow(_ stock: FilmStock) -> some View {
        let isSelected = selectedFilmStock?.id == stock.id
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedFilmStock = stock
                showCustomInput = false
                customFilmName = ""
                iso = stock.isoValue
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                // Film cover image
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
                        .foregroundStyle(
                            LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .top, endPoint: .bottom)
                        )
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

    // MARK: - Step 2: Settings (Filmer confirmation style)
    private var settingsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Basic Info section
                Text("Basic Info")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.filmTertiary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    // Camera Model
                    settingsRow(label: "Camera Model",
                                value: selectedCamera?.name ?? "None")
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
                            Text("24").tag(24)
                            Text("36").tag(36)
                        }
                        .tint(Color.filmSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    if selectedFilmStock == nil {
                        settingsDivider

                        // ISO (custom film only)
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

                // Camera selection (if cameras exist)
                if !cameras.isEmpty {
                    Text("Camera")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                        .padding(.horizontal, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cameras) { camera in
                                cameraChip(camera)
                            }
                        }
                    }
                }
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

    // MARK: - Step 3: Review & Create
    private var reviewStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Film roll visual
                VStack(spacing: 16) {
                    filmRollVisual
                    Text(filmDisplayName)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(Color.filmText)
                    Text("\(capacity) exposures · ISO \(iso) · \(format.displayName)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.filmSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                // Summary card
                VStack(spacing: 12) {
                    summaryRow(icon: "film", label: "Film", value: filmDisplayName)
                    Divider().background(Color.filmBorder)
                    summaryRow(icon: "number", label: "Exposures", value: "\(capacity)")
                    Divider().background(Color.filmBorder)
                    summaryRow(icon: "camera.aperture", label: "ISO", value: "\(iso)")
                    Divider().background(Color.filmBorder)
                    summaryRow(icon: "viewfinder", label: "Format", value: format.displayName)
                    if let cam = selectedCamera {
                        Divider().background(Color.filmBorder)
                        summaryRow(icon: "camera", label: "Camera", value: cam.name)
                    }
                    if evCompensation != 0 {
                        Divider().background(Color.filmBorder)
                        summaryRow(icon: "plusminus", label: "EV", value: String(format: "%+.1f", evCompensation))
                    }
                    if pushPull != 0 {
                        Divider().background(Color.filmBorder)
                        summaryRow(icon: "arrow.up.arrow.down", label: "Push/Pull", value: String(format: "%+.1f", pushPull))
                    }
                }
                .padding(18)
                .filmCard(cornerRadius: 20)

                // Confirm button
                Button {
                    saveRoll()
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

    // MARK: - Helpers

    private var filmDisplayName: String {
        selectedFilmStock?.displayName ?? customFilmName
    }

    private var filmRollVisual: some View {
        ZStack {
            if let stock = selectedFilmStock,
               let coverUrlString = stock.fullCoverUrl,
               let coverURL = URL(string: coverUrlString) {
                KFImage(coverURL)
                    .requestModifier(FilmerImageAuth.shared.modifier)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.filmAccent.opacity(0.2), radius: 16, x: 0, y: 8)
            } else {
                let color = selectedFilmStock?.color ?? Color.filmAccent
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.filmSurface)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "film")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(color.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.filmBorder, lineWidth: 0.5)
                    )
            }
        }
    }

    private func selectedFilmPreview(_ stock: FilmStock) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(colors: [stock.color.opacity(0.2), stock.accentColor.opacity(0.1)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 56, height: 56)

                if let coverUrlString = stock.fullCoverUrl,
                   let coverURL = URL(string: coverUrlString) {
                    KFImage(coverURL)
                        .requestModifier(FilmerImageAuth.shared.modifier)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Circle()
                        .fill(stock.color)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().fill(Color.filmBackground.opacity(0.4)).frame(width: 7, height: 7))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(stock.displayName)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(Color.filmText)
                HStack(spacing: 6) {
                    Text("ISO \(stock.isoValue)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(stock.color)
                    Text(stock.type.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
                }
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { step = 0 }
            } label: {
                Text("Change")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.filmAccent)
            }
        }
        .padding(14)
        .filmCard(cornerRadius: 18)
    }

    private var customFilmPreview: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.filmAccent.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "film")
                    .font(.system(size: 22))
                    .foregroundColor(Color.filmAccent)
            }
            Text(customFilmName)
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { step = 0 }
            } label: {
                Text("Change")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.filmAccent)
            }
        }
        .padding(14)
        .filmCard(cornerRadius: 18)
    }

    private func cameraChip(_ camera: Camera) -> some View {
        let isSelected = selectedCamera?.id == camera.id
        return Button {
            withAnimation(.spring(response: 0.25)) {
                selectedCamera = isSelected ? nil : camera
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12))
                Text(camera.name)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? Color.filmBackground : Color.filmText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(colors: [Color.filmAccent, Color.filmGold], startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.filmSurface))
            )
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.filmBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color.filmAccent)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.filmSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.filmText)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Save
    private func saveRoll() {
        let roll = Roll(
            filmName: filmDisplayName,
            camera: selectedCamera,
            capacity: capacity,
            iso: iso,
            format: format,
            evCompensation: evCompensation,
            pushPull: pushPull,
            startDate: startDate,
            notes: notes
        )
        modelContext.insert(roll)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
