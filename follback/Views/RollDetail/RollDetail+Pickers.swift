import SwiftUI
import SwiftData

extension RollDetailView {

    // MARK: - Lab Picker Sheet
    var labPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !customLabStore.labs.isEmpty {
                        Section {
                            ForEach(customLabStore.labs) { lab in
                                Button {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
    var filmPickerSheet: some View {
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

    var cameraPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // No Camera option
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
                        // Empty state with Add Camera button
                        VStack(spacing: 12) {
                            Text("No cameras yet")
                                .font(.system(size: 13))
                                .foregroundColor(Color.filmTertiary)

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showAddCameraInPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text("Add Camera")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color.filmAccent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.filmAccent.opacity(0.4), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Camera list
                        ForEach(allCameras) { camera in
                            Button {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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

                        // Add Camera button at bottom
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showAddCameraInPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Add Camera")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(Color.filmAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
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
            .sheet(isPresented: $showAddCameraInPicker) {
                NavigationStack {
                    AddCameraView()
                }
            }
        }
    }

    // MARK: - Date Picker Sheet
    var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Shooting Date", selection: $editingDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color.filmAccent)
                    .padding()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        .presentationDetents(UIDevice.current.userInterfaceIdiom == .pad ? [.height(400)] : [.medium])
    }

    // MARK: - Format Picker Sheet
    var formatPickerSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(FilmFormat.allCases, id: \.rawValue) { format in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            roll.format = format.rawValue
                            if !format.isSheet { roll.isHalfFrame = false }
                            if !format.capacityOptions.contains(roll.capacity) {
                                roll.capacity = format.defaultCapacity
                            }
                            roll.updatedAt = Date()
                            try? modelContext.save()
                            showFormatPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.filmText)
                                    Text(format.isSheet ? L("Sheet") : "")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.filmTertiary)
                                }
                                Spacer()
                                if roll.filmFormat == format {
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
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle(L("Format"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) { showFormatPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
