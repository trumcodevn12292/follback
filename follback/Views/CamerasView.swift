import SwiftUI
import SwiftData

struct CamerasView: View {
    @Query(sort: \Camera.name) var cameras: [Camera]
    @Query(sort: \Roll.createdAt, order: .reverse) var allRolls: [Roll]
    @Environment(\.modelContext) private var modelContext

    @State private var appeared = false
    @State private var showAddCamera = false
    @State private var cameraToEdit: Camera?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image("AppIconSmall")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        Text("CAMERAS")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(Color.filmText)
                            .kerning(1.5)
                    }
                    Spacer()
                    Button {
                        showAddCamera = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.filmSurface)
                                    .overlay(Circle().stroke(Color.filmBorder, lineWidth: 0.5))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appeared)

                if cameras.isEmpty {
                    emptyCamerasState
                } else {
                    cameraList
                }
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    appeared = true
                }
            }
            .sheet(isPresented: $showAddCamera) {
                AddCameraSheet()
            }
            .sheet(item: $cameraToEdit) { camera in
                EditCameraSheet(camera: camera)
            }
        }
        .background(Color.filmBackground.ignoresSafeArea())
    }

    private var emptyCamerasState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.filmTertiary.opacity(0.5))
            Text("No cameras yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.filmSecondary)
            Text("Add your cameras and lenses to track which gear you use with each roll")
                .font(.system(size: 14))
                .foregroundColor(Color.filmTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showAddCamera = true
            } label: {
                Text("Add Camera")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.filmBackground)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.filmAccent))
            }
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
    }

    private var cameraList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(cameras) { camera in
                    cameraCard(camera)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private func cameraCard(_ camera: Camera) -> some View {
        let rollCount = allRolls.filter { $0.camera?.id == camera.id }.count

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.filmSurface)
                    .frame(width: 60, height: 60)
                Image(systemName: "camera")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Color.filmTertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(camera.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.filmText)
                HStack(spacing: 8) {
                    Text(camera.brand)
                        .font(.system(size: 13))
                        .foregroundColor(Color.filmTertiary)
                    if let lens = camera.lens, !lens.isEmpty {
                        Text("•")
                            .foregroundColor(Color.filmTertiary)
                        Text(lens)
                            .font(.system(size: 13))
                            .foregroundColor(Color.filmSecondary)
                    }
                }
                Text("\(rollCount) roll\(rollCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.filmAccent)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.filmTertiary.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.filmSurface)
        )
        .onTapGesture {
            cameraToEdit = camera
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(camera)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Camera Sheet

struct AddCameraSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: ((Camera) -> Void)?

    @State private var name = ""
    @State private var brand = ""
    @State private var lens = ""
    @State private var type: CameraType = .slr
    @State private var format: FilmFormat = .mm35

    init(onSave: ((Camera) -> Void)? = nil) {
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        textFieldRow(label: "Camera Name", text: $name, placeholder: "e.g. AE-1 Program")
                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)
                        textFieldRow(label: "Brand", text: $brand, placeholder: "e.g. Canon")
                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)
                        textFieldRow(label: "Lens", text: $lens, placeholder: "e.g. 50mm f/1.4 (optional)")
                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)

                        HStack {
                            Text("Type")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Picker("", selection: $type) {
                                ForEach(CameraType.allCases, id: \.self) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .tint(Color.filmAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)

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
                            .tint(Color.filmAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.filmSurface)
                    )
                }
                .padding(16)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Add Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCamera()
                    }
                    .disabled(name.isEmpty || brand.isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func textFieldRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.filmText)
            Spacer()
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(Color.filmSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func saveCamera() {
        let camera = Camera(
            name: name,
            brand: brand,
            format: format,
            type: type,
            lens: lens.isEmpty ? nil : lens
        )
        modelContext.insert(camera)
        try? modelContext.save()
        onSave?(camera)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Edit Camera Sheet

struct EditCameraSheet: View {
    @Bindable var camera: Camera
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var lens: String = ""
    @State private var type: CameraType = .slr
    @State private var format: FilmFormat = .mm35

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 0) {
                        textFieldRow(label: "Camera Name", text: $name, placeholder: "Camera name")
                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)
                        textFieldRow(label: "Brand", text: $brand, placeholder: "Brand")
                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)
                        textFieldRow(label: "Lens", text: $lens, placeholder: "Lens (optional)")
                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)

                        HStack {
                            Text("Type")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.filmText)
                            Spacer()
                            Picker("", selection: $type) {
                                ForEach(CameraType.allCases, id: \.self) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .tint(Color.filmAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().background(Color.filmBorder.opacity(0.3)).padding(.horizontal, 16)

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
                            .tint(Color.filmAccent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.filmSurface)
                    )
                }
                .padding(16)
            }
            .background(Color.filmBackground.ignoresSafeArea())
            .navigationTitle("Edit Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || brand.isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                name = camera.name
                brand = camera.brand
                lens = camera.lens ?? ""
                type = camera.cameraType
                format = camera.filmFormat
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func textFieldRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.filmText)
            Spacer()
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(Color.filmSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func saveChanges() {
        camera.name = name
        camera.brand = brand
        camera.lens = lens.isEmpty ? nil : lens
        camera.type = type.rawValue
        camera.format = format.rawValue
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
