import SwiftUI
import SwiftData
import Kingfisher

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

                            settingsRow(format.isSheet ? L("Sheets") : L("Exposures"), value: "\(capacity)") {
                                Picker("", selection: $capacity) {
                                    if roll.isHalfFrame {
                                        Text("24").tag(24)
                                        Text("48").tag(48)
                                        Text("72").tag(72)
                                    } else {
                                        ForEach(format.capacityOptions, id: \.self) { opt in
                                            Text("\(opt)").tag(opt)
                                        }
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Color.filmAccent)
                            }
                            .onChange(of: format) { _, newFormat in
                                if !newFormat.capacityOptions.contains(capacity) {
                                    capacity = newFormat.defaultCapacity
                                }
                                if !newFormat.isSheet { roll.isHalfFrame = false }
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
