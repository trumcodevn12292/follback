import SwiftUI
import SwiftData
import Kingfisher

struct AddCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var format: FilmFormat = .mm35
    @State private var cameraType: CameraType = .slr
    @State private var fixedFocalLength = ""
    @State private var notes = ""
    @State private var cardAppeared = false
    @State private var showModelPicker = false
    @State private var selectedModel: CameraModel?
    @State private var cameraSearchText = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerCard
                modelPickerCard
                detailsCard
                notesCard
                saveButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.bottom, 40)
        }
        .background(Color.filmBackground.ignoresSafeArea())
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.filmSecondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                cardAppeared = true
            }
        }
        .sheet(isPresented: $showModelPicker) {
            cameraModelPickerSheet
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.filmGold.opacity(0.15), Color.filmGold.opacity(0.02)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 72, height: 72)

                if let model = selectedModel,
                   let coverUrlString = model.fullCoverUrl,
                   let coverURL = URL(string: coverUrlString) {
                    KFImage(coverURL)
                        .requestModifier(FilmerImageAuth.shared.modifier)
                        .downsampling(size: CGSize(width: 144, height: 144))
                        .cacheOriginalImage()
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "camera")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color.filmAccent)
                }
            }
            Text("New Camera")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color.filmText)
        }
        .frame(maxWidth: .infinity)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : -15)
    }

    // MARK: - Camera Model Picker Card

    private var modelPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Browse Camera Database")

            Button {
                showModelPicker = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.filmAccent.opacity(0.1))
                            .frame(width: 44, height: 44)

                        if let model = selectedModel,
                           let coverUrlString = model.fullCoverUrl,
                           let coverURL = URL(string: coverUrlString) {
                            KFImage(coverURL)
                                .requestModifier(FilmerImageAuth.shared.modifier)
                                .downsampling(size: CGSize(width: 88, height: 88))
                                .cacheOriginalImage()
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(Color.filmAccent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if let model = selectedModel {
                            Text(model.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.filmText)
                            Text("Tap to change")
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary)
                        } else {
                            Text("Choose from 930+ cameras")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.filmText)
                            Text("Browse the full camera database")
                                .font(.system(size: 12))
                                .foregroundColor(Color.filmTertiary)
                        }
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
                                .stroke(selectedModel != nil ? Color.filmAccent.opacity(0.3) : Color.filmBorder, lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.02), value: cardAppeared)
    }

    // MARK: - Camera Model Picker Sheet

    private var cameraModelPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(Color.filmTertiary)
                    TextField("Search cameras...", text: $cameraSearchText)
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
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                        ForEach(filteredCameraModels, id: \.brand) { group in
                            Section {
                                ForEach(group.models) { model in
                                    cameraModelRow(model)
                                }
                            } header: {
                                HStack {
                                    Text(group.brand)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color.filmSecondary)
                                        .textCase(.uppercase)
                                        .tracking(1)
                                    Spacer()
                                    Text("\(group.models.count)")
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
                    .padding(.top, 8)
                }
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Camera Database")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showModelPicker = false }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.filmAccent)
                }
            }
        }
    }

    private var filteredCameraModels: [(brand: String, models: [CameraModel])] {
        if cameraSearchText.isEmpty {
            return CameraModel.groupedByBrandPopularFirst
        }
        let query = cameraSearchText.lowercased()
        return CameraModel.groupedByBrandPopularFirst.compactMap { group in
            let filtered = group.models.filter {
                $0.displayName.lowercased().contains(query) ||
                $0.brand.lowercased().contains(query)
            }
            return filtered.isEmpty ? nil : (brand: group.brand, models: filtered)
        }
    }

    private func cameraModelRow(_ model: CameraModel) -> some View {
        let isSelected = selectedModel?.id == model.id
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedModel = model
                name = model.name
                brand = model.brand
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.filmSurface)
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.filmBorder, lineWidth: 0.5)
                        )

                    if let coverUrlString = model.fullCoverUrl,
                       let coverURL = URL(string: coverUrlString) {
                        KFImage(coverURL)
                            .requestModifier(FilmerImageAuth.shared.modifier)
                            .downsampling(size: CGSize(width: 100, height: 100))
                            .cacheOriginalImage()
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        Image(systemName: "camera")
                            .font(.system(size: 18))
                            .foregroundColor(Color.filmTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.filmText)
                    Text(model.brand)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.filmTertiary)
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

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Camera Details")

            fieldRow(label: "Name") {
                TextField("e.g. Nikon F3", text: $name)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Brand") {
                TextField("e.g. Nikon", text: $brand)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Film Format") {
                Picker("", selection: $format) {
                    ForEach(FilmFormat.allCases, id: \.self) { f in
                        Text(f.displayName).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Color.filmAccent)
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Camera Type") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CameraType.allCases, id: \.self) { type in
                            let isSelected = cameraType == type
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    cameraType = type
                                }
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } label: {
                                Text(type.displayName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Color.filmBackground : Color.filmSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                isSelected
                                                ? AnyShapeStyle(Color.filmAccent)
                                                : AnyShapeStyle(Color.filmSurfaceSecondary)
                                            )
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.clear : Color.filmBorder, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().background(Color.filmBorder)

            fieldRow(label: "Fixed Focal Length (optional)") {
                TextField("e.g. 50mm", text: $fixedFocalLength)
                    .font(.system(size: 16))
                    .foregroundColor(Color.filmText)
            }
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: cardAppeared)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Notes")
            TextEditor(text: $notes)
                .font(.system(size: 15))
                .foregroundColor(Color.filmText)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(4)
        }
        .padding(18)
        .filmCard(cornerRadius: 20)
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: cardAppeared)
    }

    private var saveButton: some View {
        Button {
            saveCamera()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                Text("Save Camera")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(Color.filmBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        name.isEmpty
                        ? AnyShapeStyle(Color.filmTertiary)
                        : AnyShapeStyle(Color.filmAccent)
                    )
                    .shadow(color: name.isEmpty ? .clear : Color.filmAccent.opacity(0.35), radius: 12, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty)
        .opacity(cardAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: cardAppeared)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color.filmSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.filmTertiary)
            content()
        }
    }

    private func saveCamera() {
        let camera = Camera(
            name: name,
            brand: brand,
            format: format,
            type: cameraType,
            fixedFocalLength: fixedFocalLength.isEmpty ? nil : Int(fixedFocalLength),
            notes: notes
        )
        modelContext.insert(camera)
        try? modelContext.save()
        dismiss()
    }
}
